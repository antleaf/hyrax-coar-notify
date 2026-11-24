# frozen_string_literal: true

module Hyrax
  module CoarNotify
    # Turns a list of work ids into the path of each work's show page, for pages (like the Notify
    # dashboard) that only hold work ids. The show path needs the work's model (/concern/datasets/:id),
    # so the models are fetched with ONE Solr query for all the ids, not one lookup per row.
    #
    # Works that can't be found (deleted, or not indexed) are left out of the result, and so is
    # everything if Solr is unreachable, so callers fall back to showing the plain id.
    class WorkPathResolver
      MODEL_FIELD = "has_model_ssim"

      # @param work_ids [Array<#to_s>]
      # @param base_path [String] app root path, normally main_app.root_path (carries any relative URL root)
      # @return [Hash{String => String}] work id => show path
      def self.call(work_ids, base_path: "/")
        new(work_ids, base_path: base_path).call
      end

      def initialize(work_ids, base_path: "/")
        @ids = Array(work_ids).map(&:to_s).reject(&:blank?).uniq
        # main_app.root_path carries default URL options (for example "/?locale=en"); only its path is wanted.
        @base = base_path.to_s.split(/[?#]/).first.to_s.chomp("/")
      end

      def call
        return {} if @ids.empty?

        documents.each_with_object({}) do |doc, paths|
          path = path_for(doc["id"], Array(doc[MODEL_FIELD]).first)
          paths[doc["id"].to_s] = path if path
        end
      rescue StandardError => e
        Rails.logger.warn("COAR Notify: could not resolve work links (#{e.class}: #{e.message})")
        {}
      end

      private

      # POST, since a dashboard page can hold up to 1000 ids, too many for a GET query string.
      def documents
        Hyrax::SolrService.query("{!terms f=id}#{@ids.join(',')}", fl: "id,#{MODEL_FIELD}", rows: @ids.size, method: :post)
      end

      def path_for(id, model)
        return if model.blank?

        # A Valkyrie model is indexed as e.g. "DatasetResource" but routed as /concern/datasets.
        route = model.to_s.delete_suffix("Resource").underscore.pluralize
        return unless route.match?(%r{\A[a-z0-9_/]+\z})

        "#{@base}/concern/#{route}/#{id}"
      end
    end
  end
end
