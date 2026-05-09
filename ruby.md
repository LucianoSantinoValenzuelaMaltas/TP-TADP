sasdadsa

* Symbol: Es el nombre inmutable que Ruby usa para identificar el atributo o el método. 
  Básicamente, es cualquier cosa con : delante, por ejemplo :nombre.

* def dentro de un def define el método en la singleton class del objeto, salvo en main, que lo hace en object

* define_method es un método para la instancia del self correspondiente al contexto actual.

* Puedo hacer @variable en un objeto, de hecho, eso es una de las cosas que hace attr_accesor

* instance_variable_get rompe ENCAPSULAMIENTO

* send devuelve siempre el getter, porque el setter se guarda como "#{nombre}="

* 