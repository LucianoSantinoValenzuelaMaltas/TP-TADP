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
      def save!
        if @id.nil?
          define_singleton_method("id") do
            @id
          end
        end
        @id = self.class.save!(self)
      end

      def refresh!
        if @id.nil?
          raise "Falla! Este objeto no tiene id!"
        end
        
        mi_entrada = self.class.refresh!(self.id)
        self.class.tipos.keys.each {|atributo| self.send("#{atributo}=", mi_entrada[atributo])}
      end

      def forget!
        if @id.nil?
          raise "Falla! Este objeto no tiene id!"
        end

        self.class.forget!(self.id)
        self.remove_instance_variable("@id")
      end
end

class Tabla
  def initialize(owner)
    @owner = owner
    @tabla = TADB::DB.table("#{owner}")
  end

      def method_missing(nombre_metodo, *argumentos, &block)
        if nombre_metodo.to_s.start_with?("find_by_")
          lista_de_objetos = self.all_instances
          return lista_de_objetos.select { |objeto| objeto.send(nombre_metodo.to_s.delete_prefix("find_by_")) === argumentos.first}      
        else
          super(nombre_metodo, *argumentos, &block)
        end
      end

      def respond_to_missing?(nombre_metodo, include_private = false)
        nombre_metodo.to_s.start_with?("find_by_") || super(nombre_metodo, include_private = false)
      end

      def all_instances
        hashees = @tabla.entries

        objetos_persisitidos = []

        hashees.each {|hash| objetos_persisitidos.append(@owner.crear_segun_hash(hash))}
        
        return objetos_persisitidos
      end


      def forget!(id)
        @tabla.delete(id)
      end

      def refresh!(id)
        @tabla.entries.find {|hash| hash[:id] == id}
      end

      def save!(objeto)
        valores = {}

        @owner.tipos.keys.each do |atributo|
          if objeto.send(atributo).respond_to?(:save!)
            id = objeto.send(atributo).save! 
            valores[atributo] = id
          else
            valores[atributo] = objeto.send("#{atributo}")
          end
        end

        if !objeto.id.nil?
          valores[:id] = objeto.id
          self.forget!(objeto.id)
        end 

        @tabla.insert(valores)
      end
end

class Class
  def has_one(tipo, descripcion)
    attr_accessor descripcion[:named]

    @tabla = Tabla.new(self)

    if @tipos.nil?
      define_singleton_method("method_missing") do |nombre_metodo, *argumentos, &block|
        if @tabla.respond_to?(nombre_metodo)
          @tabla.send(nombre_metodo, *argumentos, &block)    
        else
          super(nombre_metodo, *argumentos, &block)
        end
      end

      define_singleton_method("respond_to_missing?") do |nombre_metodo, include_private = false|
        @tabla.respond_to?(nombre_metodo) || super(nombre_metodo, include_private = false)
      end
      
      @tipos = {}

      @tipos[descripcion[:named]] = tipo

      define_singleton_method("tipos") do
        @tipos
      end

      define_singleton_method("tabla") do
        @tabla
      end

      define_singleton_method("crear_segun_hash") do |hash|
        instancia = self.new

        instancia.define_singleton_method("id") do
            @id
          end
        instancia.define_singleton_method("id=") do |valor|
          @id = valor
        end

        hash.keys.each do |atributo|
          # puts atributo
          if atributo != :id && @tipos[atributo].instance_methods.include?(:save!)
            objeto_atributo = @tipos[atributo].crear_segun_hash(@tipos[atributo].refresh!(hash[atributo]))
            instancia.send("#{atributo}=", objeto_atributo)
          else
            instancia.send("#{atributo}=", hash[atributo])
          end
        end
        return instancia
      end

      self.include(Persistible)

    else
       @tipos[descripcion[:named]] = tipo
    end
  end

  def has_many(tipo, descripcion)
    self.has_one(tipo, descripcion)
    self.instance_variable_set(descripcion[:named],[])
    
    define_method(descripcion[:named].to_s) do
      "@#{descripcion[:named].to_s}"
    end
    
    define_method("#{descripcion[:named].to_s}=") do |valor|
      "@#{descripcion[:named].to_s}" = valor
    end

    #Una variable compartida que la inicializó como lista y ya está :P

  end
end

class Auto
  has_one String, named: :marca
  has_one String, named: :modelo
end

class Person

  has_one String, named: :first_name

  has_one String, named: :last_name

  has_one Numeric, named: :age

  has_one Boolean, named: :admin

  has_one Auto, named: :auto

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

camaro = Auto.new
camaro.marca = "Chevrolet"
camaro.modelo = "Camaro ZL1"

tt = Auto.new
tt.marca = "Audi"
tt.modelo = "TT RS"

a1.first_name = "Luciano"
a1.last_name = "Valenzuela"
a1.age = 22
a1.admin = true
a1.auto = camaro

a2.first_name = "Natalia"
a2.last_name = "Maltas"
a2.age = 49
a2.admin = false
a2.auto = tt

a1.save!

puts Person.all_instances
puts Person.all_instances.at(0).auto.modelo

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
#puts Person.find_by_has_last_name("Maltas")

#Person.tabla.clear

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

#binding.pry

