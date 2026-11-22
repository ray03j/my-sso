module Auth
  # RP の redirect_uri に、元のクエリを保ったままパラメータ（code / error / state）を付ける
  module RedirectUri
    def self.build(redirect_uri, params)
      uri = URI.parse(redirect_uri)
      query = Rack::Utils.parse_query(uri.query).merge(params.stringify_keys.compact_blank)
      uri.query = Rack::Utils.build_nested_query(query)
      uri.to_s
    end
  end
end
