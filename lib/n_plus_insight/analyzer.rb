module NPlusInsight
  class Analyzer
    def initialize(request:, queries:)
      @request = request
      @queries = queries
    end

    def call
      repeated_shapes = @queries.group_by { |query| repeated_shape_key(query) }.values.select do |queries|
        queries.length >= NPlusInsight.configuration.minimum_repetitions
      end

      repeated_shapes
        .group_by { |queries| location_key(dominant_location(queries), queries.first.binds_signature) }
        .map { |_key, query_groups| build_detection(query_groups) }
    end

    private

    def repeated_shape_key(query)
      location = query.location
      [query.binds_signature, location&.path, location&.line]
    end

    def build_detection(query_groups)
      location = dominant_location(query_groups.flatten)
      timeline_origin = query_groups.flatten.filter_map(&:started_at).map(&:to_f).min
      graph_models = {}
      graph_edges = []

      serialized_groups = query_groups.map do |queries|
        tables = queries.flat_map(&:tables).uniq
        model_map = model_map_for(tables)
        inferred = infer_owner(model_map.values, location)

        add_models(graph_models, tables, model_map, inferred)
        graph_edges.concat(edges_for(model_map, inferred))

        {
          sql: queries.first.normalized_sql,
          query_count: queries.length,
          total_ms: queries.sum(&:duration_ms).round(2),
          tables: tables,
          waterfall: serialize_waterfall(queries, timeline_origin)
        }
      end

      edges = graph_edges.uniq { |edge| [edge[:from], edge[:to], edge[:association]] }
      models = graph_models.values

      Detection.new(
        id: SecureRandom.uuid,
        request_id: @request[:request_id],
        method: @request[:method],
        path: @request[:path],
        created_at: Time.now.utc.iso8601,
        query_count: serialized_groups.sum { |group| group[:query_count] },
        total_ms: serialized_groups.sum { |group| group[:total_ms] }.round(2),
        waterfall_ms: waterfall_span(query_groups.flatten, timeline_origin),
        sql: serialized_groups.first[:sql],
        query_groups: serialized_groups,
        location: location,
        models: models,
        edges: edges,
        tree: build_forest(models, edges),
        suggestions: suggestions(edges, location)
      )
    end

    def serialize_waterfall(queries, timeline_origin)
      fallback_offset = 0.0

      queries
        .each_with_index
        .sort_by { |query, index| [query.started_at ? query.started_at.to_f : Float::INFINITY, index] }
        .map.with_index do |(query, _original_index), index|
          duration = query.duration_ms.to_f
          offset = if timeline_origin && query.started_at
            (query.started_at.to_f - timeline_origin) * 1000
          else
            fallback_offset
          end
          fallback_offset = [fallback_offset, offset + duration].max

          {
            index: index + 1,
            name: query.name,
            offset_ms: offset.round(2),
            duration_ms: duration.round(2)
          }
        end
    end

    def waterfall_span(queries, timeline_origin)
      if timeline_origin
        finishes = queries.filter_map do |query|
          next unless query.started_at

          ((query.started_at.to_f - timeline_origin) * 1000) + query.duration_ms.to_f
        end
        return finishes.max.to_f.round(2) if finishes.any?
      end

      queries.sum { |query| query.duration_ms.to_f }.round(2)
    end

    def dominant_location(queries)
      queries
        .filter_map(&:location)
        .group_by { |item| [item.path, item.line] }
        .max_by { |_key, values| values.length }
        &.last
        &.first
    end

    def location_key(location, fallback)
      location ? [location.path, location.line] : [:query_shape, fallback]
    end

    def add_models(graph_models, tables, model_map, inferred)
      tables.each do |table|
        model = model_map[table]
        name = model&.name || table.classify
        graph_models[name] ||= { table: table, name: name, primary: false }
        graph_models[name][:primary] = true
      end

      return unless inferred

      [inferred[:owner], inferred[:target]].each do |model|
        graph_models[model.name] ||= {
          table: model.table_name,
          name: model.name,
          primary: tables.include?(model.table_name)
        }
      end
    end

    def edges_for(model_map, inferred)
      if inferred
        [{
          from: inferred[:owner].name,
          to: inferred[:target].name,
          association: inferred[:reflection].name,
          macro: inferred[:reflection].macro
        }]
      else
        association_edges(model_map)
      end
    end

    def model_map_for(tables)
      return {} unless defined?(ActiveRecord::Base)

      if defined?(Rails) &&
          Rails.respond_to?(:application) &&
          Rails.application&.config&.eager_load &&
          ActiveRecord::Base.descendants.empty?
        Rails.application.eager_load!
      end

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

          {
            from: model.name,
            to: target.name,
            association: reflection.name,
            macro: reflection.macro
          }
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
        candidates.find do |item|
          source.match?(/\.\s*#{Regexp.escape(item[:reflection].name.to_s)}\b/)
        end ||
        candidates.min_by { |item| item[:reflection].macro == :belongs_to ? 1 : 0 }
    end

    def build_forest(models, edges)
      models_by_name = models.to_h { |model| [model[:name], model] }
      children = edges.group_by { |edge| edge[:from] }
      child_names = edges.map { |edge| edge[:to] }
      roots = models.map { |model| model[:name] }.reject { |name| child_names.include?(name) }
      roots = [models.first[:name]] if roots.empty? && models.any?

      roots.filter_map do |name|
        build_tree_node(name, models_by_name, children, [])
      end
    end

    def build_tree_node(name, models_by_name, children, ancestors, association = nil, macro = nil)
      return if ancestors.include?(name)

      model = models_by_name[name] || { name: name, table: name.to_s.tableize }
      next_ancestors = ancestors + [name]
      {
        name: model[:name],
        table: model[:table],
        association: association,
        macro: macro,
        children: children.fetch(name, []).filter_map do |edge|
          build_tree_node(
            edge[:to],
            models_by_name,
            children,
            next_ancestors,
            edge[:association],
            edge[:macro]
          )
        end
      }
    end

    def suggestions(edges, location)
      roots = (edges.map { |edge| edge[:from] } - edges.map { |edge| edge[:to] }).uniq
      roots = [edges.first[:from]] if roots.empty? && edges.any?
      eager_load = roots.map { |root| eager_load_for(root, edges) }.compact.join("\n")
      eager_load = "ParentModel.includes(:association)" if eager_load.empty?
      strict_loading = roots.any? ? roots.map { |root| "#{root}.strict_loading" }.join("\n") : "ParentModel.strict_loading"
      association_count = edges.map { |edge| [edge[:from], edge[:association]] }.uniq.length

      results = [
        {
          title: association_count > 1 ? "Eager-load all affected associations" : "Eager-load the association",
          code: eager_load,
          explanation: association_count > 1 ?
            "Preload the complete association tree before this source line executes." :
            "Load related rows in a bounded number of queries before the loop renders them.",
          confidence: edges.any? ? "high" : "medium"
        },
        {
          title: "Use strict loading to prevent regressions",
          code: strict_loading,
          explanation: "Rails will raise when code lazily loads an association that was not preloaded.",
          confidence: "medium"
        }
      ]

      if location
        results.unshift(
          title: association_count > 1 ? "Change the relation feeding this call site" : "Change the relation feeding this line",
          code: "# #{location.path}:#{location.line}\n#{eager_load}",
          explanation: "Apply eager loading where the root relation is constructed, not inside the iteration.",
          confidence: edges.any? ? "high" : "medium"
        )
      end

      results
    end

    def eager_load_for(root, edges)
      children = edges.group_by { |edge| edge[:from] }
      associations = format_associations(root, children, [])
      return if associations.empty?

      "#{root}.includes(#{associations.join(', ')})"
    end

    def format_associations(model_name, children, ancestors)
      return [] if ancestors.include?(model_name)

      children.fetch(model_name, []).map do |edge|
        nested = format_associations(edge[:to], children, ancestors + [model_name])
        if nested.empty?
          ":#{edge[:association]}"
        else
          value = nested.one? ? nested.first : "[#{nested.join(', ')}]"
          "{ #{edge[:association]}: #{value} }"
        end
      end
    end
  end
end
