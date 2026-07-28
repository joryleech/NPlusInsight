module NPlusInsight
  class Analyzer
    def initialize(request:, queries:)
      @request = request
      @queries = queries
    end

    def call
      groups = @queries.group_by(&:binds_signature)
      groups.filter_map do |_shape, queries|
        next if queries.length < NPlusInsight.configuration.minimum_repetitions
        build_detection(queries)
      end
    end

    private

    def build_detection(queries)
      tables = queries.flat_map(&:tables).uniq
      model_map = model_map_for(tables)
      location = queries.filter_map(&:location).group_by { |item| [item.path, item.line] }.max_by { |_key, values| values.length }&.last&.first
      inferred = infer_owner(model_map.values, location)
      graph_models = ([inferred&.fetch(:owner, nil)] + model_map.values).compact.uniq
      models = graph_models.map { |model| { table: model.table_name, name: model.name, primary: tables.include?(model.table_name) } }
      models = tables.map { |table| { table: table, name: table.classify, primary: true } } if models.empty?
      edges = inferred ? [{ from: inferred[:owner].name, to: inferred[:target].name, association: inferred[:reflection].name, macro: inferred[:reflection].macro }] : association_edges(model_map)

      Detection.new(
        id: SecureRandom.uuid,
        request_id: @request[:request_id],
        method: @request[:method],
        path: @request[:path],
        created_at: Time.now.utc.iso8601,
        query_count: queries.length,
        total_ms: queries.sum(&:duration_ms).round(2),
        sql: queries.first.normalized_sql,
        location: location,
        models: models,
        edges: edges,
        suggestions: suggestions(model_map, tables, location, inferred)
      )
    end

    def model_map_for(tables)
      return {} unless defined?(ActiveRecord::Base)
      Rails.application.eager_load! if Rails.application.config.eager_load && ActiveRecord::Base.descendants.empty?
      ActiveRecord::Base.descendants.each_with_object({}) do |model, map|
        map[model.table_name] = model unless model.abstract_class?
      rescue StandardError
        next
      end.slice(*tables)
    end

    def association_edges(model_map)
      model_map.values.flat_map do |model|
        model.reflect_on_all_associations.filter_map do |reflection|
          target = reflection.klass rescue nil
          next unless target && model_map.value?(target)
          { from: model.name, to: target.name, association: reflection.name, macro: reflection.macro }
        end
      end.uniq
    end

    def infer_owner(targets, location)
      return unless defined?(ActiveRecord::Base)
      candidates = ActiveRecord::Base.descendants.flat_map do |owner|
        owner.reflect_on_all_associations.filter_map do |reflection|
          target = reflection.klass rescue nil
          { owner: owner, target: target, reflection: reflection } if targets.include?(target)
        end
      rescue StandardError
        []
      end
      source = location&.snippet.to_a.map { |line| line[:text] }.join(" ")
      receiver_match = candidates.find do |item|
        owner_name = item[:owner].model_name.element
        association_name = item[:reflection].name
        source.match?(/(?:@|\b)#{Regexp.escape(owner_name)}\.#{Regexp.escape(association_name.to_s)}\b/i)
      end
      receiver_match ||
        candidates.find { |item| source.match?(/\b#{Regexp.escape(item[:reflection].name.to_s)}\b/) } ||
        candidates.first
    end

    def suggestions(model_map, tables, location, inferred)
      edges = inferred ? [{ from: inferred[:owner].name, association: inferred[:reflection].name }] : association_edges(model_map)
      association = edges.first&.fetch(:association, nil)
      owner = edges.first&.fetch(:from, nil)
      relation = owner || "ParentModel"
      eager_load = association ? "#{relation}.includes(:#{association})" : "ParentModel.includes(:association)"

      results = [
        {
          title: "Eager-load the association",
          code: eager_load,
          explanation: "Load related rows in a bounded number of queries before the loop renders them.",
          confidence: association ? "high" : "medium"
        },
        {
          title: "Use strict loading to prevent regressions",
          code: "#{relation}.strict_loading",
          explanation: "Rails will raise when code lazily loads an association that was not preloaded.",
          confidence: "medium"
        }
      ]
      if location
        results.unshift(
          title: "Change the relation feeding this line",
          code: "# #{location.path}:#{location.line}\n#{eager_load}",
          explanation: "Apply eager loading where the parent relation is constructed, not inside the iteration.",
          confidence: association ? "high" : "medium"
        )
      end
      results
    end
  end
end
