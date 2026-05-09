module Autoritario
  def gritar
    puts "#{self.class.name.upcase}!"
  end
end

class Persona
  include Autoritario
end

Persona.new.gritar # => "PERSONA!"


##############################################################################################################################


class Module
  def validar_presencia(*atributos)
    atributos.each do |atributo| 
        attr_accessor atributo

        define_method("#{atributo}_presente?") do
          valor = instance_variable_get("@#{atributo}")
          
          !valor.nil? && !valor.empty?
        end
    end
    
  end
end


class Persona
  validar_presencia :nombre, :email
end

p = Persona.new
p.nombre = "Juan"
puts p.nombre_presente? # Debería devolver true


##############################################################################################################################


class Module
  def anotar(clave, valor)
    @persiste ||= {}
    @persiste[clave] = valor
  end

  def leer_nota(clave)
    puts @persiste[clave]
    #atributo = instance_variable_get("@persiste")
    #puts atributo[clave]
    #No hace falta hacer "#{clave} porque la idea es pasar el : delante del parámetro"

    #La IA recomienda esto
    puts @persiste ? @persiste[clave] : nil
  end
end


class Persona
  anotar :autor, "Tu Nombre"
end

Persona.leer_nota(:autor) # => "Tu Nombre"