# 1)
require 'pry'

require 'tadb'

module Boolean
end

class TrueClass
  include Boolean
end

class FalseClass
  include Boolean
end

module Persistible

end

class Class
  def has_one(tipo, descripcion)
    attr_accessor descripcion[:named]

    @tabla = TADB::DB.table("#{self}")

    if @tipos.nil?
      define_singleton_method("method_missing") do |nombre_metodo, *argumentos, &block|
        if nombre_metodo.to_s.start_with?("find_by_")
          lista_de_objetos = @tabla.entries.map { |hash| self.crear_segun_hash(hash)}
          return lista_de_objetos.select { |objeto| objeto.send(nombre_metodo.to_s.delete_prefix("find_by_")) === argumentos.first}      
        else
          super
        end
      end

      define_singleton_method("respond_to_missing?") do |nombre_metodo, include_private = false|
        nombre_metodo.to_s.start_with?("find_by_") || super
      end
      
      @tipos = {}

      @tipos[descripcion[:named]] = tipo

      define_singleton_method("tipos") do
        @tipos
      end

      define_singleton_method("tabla") do
        @tabla
      end

      define_singleton_method("remover_entrada") do |id|
        @tabla.delete(id)
      end

      define_singleton_method("nueva_entrada") do |instancia|
        valores = {}
        @tipos.keys.each {|atributo| valores[atributo] = instancia.send("#{atributo}")}
        @tabla.insert(valores)
      end

      define_singleton_method("actualizar_entrada") do |instancia|
        valores = {}
        @tipos.keys.each {|atributo| valores[atributo] = instancia.send("#{atributo}")}
        valores[:id] = instancia.id
        self.remover_entrada(instancia.id)
        @tabla.insert(valores)
      end

      define_method("save!") do
        if @id.nil?
          define_singleton_method("id") do
            @id
          end

          @id = self.class.nueva_entrada(self)
        
        else          
          self.class.actualizar_entrada(self)
        end
      end

      define_method("refresh!") do
        if @id.nil?
          raise "Falla! Este objeto no tiene id!"
        end
        
        mi_entrada = self.class.tabla.entries.find {|hash| hash[:id] == self.id}
        self.class.tipos.keys.each {|atributo| self.send("#{atributo}=", mi_entrada[atributo])}
      end

      define_method("forget!") do
        if @id.nil?
          raise "Falla! Este objeto no tiene id!"
        end

        self.class.remover_entrada(self.id)
        self.remove_instance_variable("@id")
      end

      define_singleton_method("all_instances") do
        hashees = @tabla.entries

        objetos_persisitidos = []

        hashees.each {|hash| objetos_persisitidos.append(self.crear_segun_hash(hash))}
        
        return objetos_persisitidos
      end

      define_singleton_method("crear_segun_hash") do |hash|
        instancia = self.new

        instancia.define_singleton_method("id") do
            @id
          end
        instancia.define_singleton_method("id=") do |valor|
          @id = valor
        end

        hash.keys.each {|clave| instancia.send("#{clave}=", hash[clave])}
        return instancia
      end

    else
       @tipos[descripcion[:named]] = tipo
    end
  end
end


class Person

  has_one String, named: :first_name

  has_one String, named: :last_name

  has_one Numeric, named: :age

  has_one Boolean, named: :admin

  attr_accessor :some_other_non_persistible_attribute

  def es_mayor?
    self.age > 17
  end
  def has_last_name(last_name)
    self.last_name == last_name
  end



end

puts Person.new.respond_to?(:first_name)
puts Person.new.respond_to?(:save!)

a1 = Person.new
a2 = Person.new

a1.first_name = "Luciano"
a1.last_name = "Valenzuela"
a1.age = 22
a1.admin = true

a2.first_name = "Natalia"
a2.last_name = "Maltas"
a2.age = 49
a2.admin = false

a1.save!

puts Person.all_instances

a2.save!

puts Person.all_instances.at(1).first_name
puts Person.all_instances.at(1).id

a3 = Person.all_instances.at(1)
a3.first_name = "Natalia Silvia"
a3.save!

a1.last_name = "Maltas"
a1.save!

puts Person.respond_to?("find_by_id")
puts Person.respond_to?("find_by_first_name")
puts Person.respond_to?("find_by_last_name")
puts Person.respond_to?("find_by_age")
puts Person.respond_to?("find_by_admin")
#puts Person.singleton_class.instance_methods

puts Person.find_by_age(22)
puts Person.find_by_last_name("Maltas")
puts "find_by de mensajes"
puts Person.find_by_es_mayor?(false)
puts Person.find_by_has_last_name("Maltas")

Person.tabla.clear

# puts a1.first_name

# a1.save!

# puts a1.id

# a1.first_name = "Santino"

# puts a1.first_name

# a1.refresh!

# puts a1.first_name

# a1.last_name = "Valenzuela Maltas"
# a1.save!


# a1.forget!

# puts a1.id.nil?

# Person.new.refresh!

binding.pry

