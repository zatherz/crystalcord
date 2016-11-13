module CrystalCord
  class Util
    macro wrap(name)
		  @cache : CrystalCord::Cache

		  def initialize(@{{name.var.id}} : {{name.type}}, @client : CrystalCord::Client)
    	  @cache = @client.cache
		  end

      def self.from_json(str : String, client : CrystalCord::Client)
        self.new({{name.type.id}}.from_json(str), client)
      end
	  end

    macro alias(name, target)
	  	def {{name.id}}(*args)
	  		{{target.id}}(*args)
	  	end
	  end

    macro delegate_alias(*pairs, to target)
      {% for pair in pairs %}
        def {{pair[0].id}}(*args)
          {{target.id}}.{{pair[1].id}}(*args)
        end
      {% end %}
    end

    macro delegate_not_nil!(*names, to target)
      {% for name in names %}
        def {{name.id}}(*args)
          v = {{target.id}}.{{name.id}}(*args)
          raise "Nil assertion failed! (#{{{name.id}}})" if v.nil?
          v
        end
      {% end %}
    end
  end
end
