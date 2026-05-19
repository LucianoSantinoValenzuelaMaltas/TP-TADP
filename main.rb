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
      define_singleton_method('id') do
        @id
      end
    end
    @id = self.class.save!(self)
  end

  def refresh!
    raise 'Falla! Este objeto no tiene id!' if @id.nil?

    mi_entrada = self.class.refresh!(id)
    self.class.tipos.keys.each { |atributo| send("#{atributo}=", mi_entrada[atributo]) }
  end

  def forget!
    raise 'Falla! Este objeto no tiene id!' if @id.nil?

    self.class.forget!(id)
    remove_instance_variable('@id')
  end
end

class Tabla
  def initialize(owner)
    @owner = owner
    @tabla = TADB::DB.table("#{owner}")
  end

  def eliminar_tabla
    @tabla.clear
  end

  def method_missing(nombre_metodo, *argumentos, &block)
    if nombre_metodo.to_s.start_with?('find_by_')
      lista_de_objetos = all_instances
      lista_de_objetos.select do |objeto|
        objeto.send(nombre_metodo.to_s.delete_prefix('find_by_')) === argumentos.first
      end
    else
      super(nombre_metodo, *argumentos, &block)
    end
  end

  def respond_to_missing?(nombre_metodo, _include_private = false)
    nombre_metodo.to_s.start_with?('find_by_') || super(nombre_metodo, false)
  end

  def all_instances
    hashees = @tabla.entries

    objetos_persisitidos = []

    hashees.each { |hash| objetos_persisitidos.append(@owner.crear_segun_hash(hash)) }

    objetos_persisitidos
  end

  def forget!(id)
    @tabla.delete(id)
    # Debería eliminar también las tablas hijas
  end

  def refresh!(id)
    @tabla.entries.find { |hash| hash[:id] == id } # Modificar el método refresh en Persistible
  end

  def crear_entrada_sin_array(objeto, atributos_lista)
    entrada = {}

    atributos_lista.each do |atributo|
      if objeto.send(atributo).respond_to?(:save!)
        id = objeto.send(atributo).save!
        entrada[atributo] = id
      else
        entrada[atributo] = objeto.send("#{atributo}")
      end
    end

    unless objeto.id.nil?
      entrada[:id] = objeto.id
      forget!(objeto.id)
    end

    entrada
  end

  def crear_entrada_array(array)
    conjunto_ids = []
    array.each { |elemento| conjunto_ids.push(elemento.save!) }
    conjunto_ids.join(',') # String de ids separados c/u por una coma
  end

  def save!(objeto)
    if @owner.tipos.keys.any? { |atributo| objeto.send(atributo).is_a?(Array) }
      atributos_listas = objeto.class.tipos.keys.select { |atributo| objeto.send(atributo).is_a?(Array) }
      atributos_comunes = objeto.class.tipos.keys.select { |atributo| !objeto.send(atributo).is_a?(Array) }
      hash = crear_entrada_sin_array(objeto, atributos_comunes)
      atributos_listas.each { |atributo| hash[atributo] = crear_entrada_array(objeto.send(atributo)) }
      @tabla.insert(hash)
    else
      @tabla.insert(crear_entrada_sin_array(objeto, objeto.class.tipos.keys))
    end
  end
end

class Class
  def has_one(tipo, descripcion)
    attr_accessor descripcion[:named]

    @tabla = Tabla.new(self)

    if @tipos.nil?
      define_singleton_method('method_missing') do |nombre_metodo, *argumentos, &block|
        if @tabla.respond_to?(nombre_metodo)
          @tabla.send(nombre_metodo, *argumentos, &block)
        else
          super(nombre_metodo, *argumentos, &block)
        end
      end

      define_singleton_method('respond_to_missing?') do |nombre_metodo, _include_private = false|
        @tabla.respond_to?(nombre_metodo) || super(nombre_metodo, false)
      end

      @tipos = {}

      @tipos[descripcion[:named]] = tipo

      define_singleton_method('tipos') do
        @tipos
      end

      define_singleton_method('tabla') do
        @tabla
      end

      define_singleton_method('crear_segun_hash') do |hash|
        instancia = new

        instancia.define_singleton_method('id') do
          @id
        end
        instancia.define_singleton_method('id=') do |valor|
          @id = valor
        end

        instancia.send(:id=, hash[:id])

        @tipos.keys.each do |atributo|
          if instancia.send(atributo).is_a?(Array)
            hash[atributo].split(',').each do |id|
              instancia.send(atributo).push(@tipos[atributo].crear_segun_hash(@tipos[atributo].refresh!(id)))
            end

          elsif @tipos[atributo].instance_methods.include?(:save!)
            objeto = @tipos[atributo].crear_segun_hash(@tipos[atributo].refresh!(hash[atributo]))
            instancia.send("#{atributo}=", objeto)

          else
            instancia.send("#{atributo}=", hash[atributo])
          end
        end

        instancia
      end

      include(Persistible)

    else
      @tipos[descripcion[:named]] = tipo
    end
  end

  def has_many(tipo, descripcion)
    if @listas_many.nil?
      @listas_many = []

      define_singleton_method('manys') do
        @listas_many
      end

      define_method('initialize') do
        self.class.manys.each { |elemento| instance_variable_set(elemento, []) }
      end
    end

    @listas_many.push("@#{descripcion[:named]}")

    has_one(tipo, descripcion)
  end
end

class Auto
  has_one String, named: :marca
  has_one String, named: :modelo
end

class Celular
  has_one String, named: :marca
  has_one String, named: :modelo
end

class Person
  has_one String, named: :first_name

  has_one String, named: :last_name

  has_one Numeric, named: :age

  has_one Boolean, named: :admin

  has_one Celular, named: :celular

  has_many Auto, named: :autos

  attr_accessor :some_other_non_persistible_attribute

  def es_mayor?
    age > 17
  end

  def has_last_name(last_name)
    self.last_name == last_name
  end
end

puts Person.new.respond_to?(:first_name)
puts Person.new.respond_to?(:save!)
puts Person.new.respond_to?(:autos)

a1 = Person.new
a2 = Person.new

camaro = Auto.new
camaro.marca = 'Chevrolet'
camaro.modelo = 'Camaro ZL1'

corvette = Auto.new
corvette.marca = 'Chevrolet'
corvette.modelo = 'Corvette ZR1'

tt = Auto.new
tt.marca = 'Audi'
tt.modelo = 'TT RS'

a31 = Celular.new
a31.marca = 'Samsung'
a31.modelo = 'A31'

note15 = Celular.new
note15.marca = 'Xiaomi'
note15.modelo = 'Note 15'

a1.first_name = 'Luciano'
a1.last_name = 'Valenzuela'
a1.age = 22
a1.admin = true
a1.celular = a31
a1.autos.push(camaro)
a1.autos.push(corvette)
# p a1

a2.first_name = 'Natalia'
a2.last_name = 'Maltas'
a2.age = 49
a2.admin = false
a2.celular = note15
a2.autos.push(tt)
# p a2

a1.save!

p Person.all_instances
# p Person.all_instances.at(0).auto.modelo

# a2.save!

# puts Person.all_instances.at(1).first_name
# puts Person.all_instances.at(1).id

# a3 = Person.all_instances.at(1)
# a3.first_name = "Natalia Silvia"
# a3.save!

# a1.last_name = "Maltas"
# a1.save!

# puts Person.respond_to?("find_by_id")
# puts Person.respond_to?("find_by_first_name")
# puts Person.respond_to?("find_by_last_name")
# puts Person.respond_to?("find_by_age")
# puts Person.respond_to?("find_by_admin")
# #puts Person.singleton_class.instance_methods

# puts Person.find_by_age(22)
# puts Person.find_by_last_name("Maltas")
# puts "find_by de mensajes"
# puts Person.find_by_es_mayor?(false)
# puts Person.find_by_has_last_name("Maltas")

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

# binding.pry

class Piloto < Person
  has_one String, named: :licencia
end

p Piloto.instance_methods.include?(:first_name)
p Piloto.instance_methods.include?(:last_name)
p Piloto.instance_methods.include?(:admin)
p Piloto.instance_methods.include?(:age)
p Piloto.instance_methods.include?(:celular)
p Piloto.instance_methods.include?(:autos)
p Piloto.instance_methods.include?(:licencia)

f1 = Auto.new
f1.marca = 'Red Bull'
f1.modelo = 'F1 2026'

s26 = Celular.new
s26.marca = 'Samsung'
s26.modelo = 'S26 Ultra'

Person.tabla.eliminar_tabla
Celular.tabla.eliminar_tabla
Auto.tabla.eliminar_tabla

max = Piloto.new
max.first_name = 'Max'
max.last_name = 'Verstappen'
max.age = 22
max.admin = true
max.celular = s26
max.autos.push(f1)

max.save!

# binding pry
