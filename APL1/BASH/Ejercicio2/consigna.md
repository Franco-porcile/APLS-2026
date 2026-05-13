# Testear su uso
```bash
./ejercicio2.sh -a test.txt | diff - test_esperado.txt
```
- O con salida a archivo:
```bash
./ejercicio2.sh -a test.txt -s test_salida.txt
diff test_salida.txt test_esperado.txt
```

- Si al realizar el diff no se muestra nada, el resultado es correcto.

# Objetivos
Manipulación de texto, uso de expresiones regulares y herramientas estándar del
sistema. 

# Consigna
Implementar un script que lea un texto sin formato y aplique una serie de arreglos automáticos para
adecuarlo a las convenciones del idioma español.
El script deberá:
- Recibir un archivo de texto como parámetro.
- Procesarlo línea por línea o como un todo.
- Mostrar el texto corregido por salida estándar o guardarlo en un nuevo archivo

# Reglas - Hechas
El script deberá aplicar al menos las siguientes correcciones. Se pueden implementar más, siempre que
estén correctamente documentadas.

## 1. Puntuacion
- `[X]` Asegurar que cada párrafo finalice con un punto, signo de cierre de interrogación (?) o exclamación
(!) según corresponda.
- `[X]` Eliminar espacios innecesarios antes de los signos de puntuación (.,;:?!).
- `[X]` Asegurar un único espacio después de los signos de puntuación, cuando corresponda.

## 2. Mayúsculas
- `[X]` Convertir a mayúscula la primera letra:
    - Del texto.
    - De cada oración después de un punto.
    - Después de signos de cierre (?, !).
- `[X]` Convertir a mayúscula los pronombres personales “Yo” cuando correspondan (opcional, nivel
avanzado).

## 3. Signos de interrogación y exclamación
- `[X]` Verificar que toda pregunta tenga signos de apertura y cierre (¿ ?).
- `[X]` Verificar que toda exclamación tenga signos de apertura y cierre (¡ !).
    Ejemplo: como estas? → ¿Cómo estas?

## 4. Espaciado y formato
- `[X]` Eliminar espacios múltiples consecutivos y reemplazarlos por un solo espacio.
- `[X]` Eliminar espacios al inicio y al final de cada línea.

## 5. Normalización de caracteres
- `[X]` Unificar comillas simples o dobles.
- `[X]` Reemplazar puntos suspensivos mal escritos (....) por ....

# Parámetros - Pendiente
Tabla:
| Parámetro bash | Parámetro PowerShell | Descripción |
|----------------|----------------------|-------------|
| `-a` / `--archivo` | `-archivo` | Archivo de entrada. |
| `-s / --salida` | `-salida` | Archivo de salida (opcional, se muestra por pantalla si no se informa) |

# Fixes
- Que detecte mas de un signo de apertura o cierre y deje 1 solo. Resuelta pero posible eliminado de mas si se quiere usar !?. REVISAR.
- Que no ponga mayus si son puntos suspensivos. Igual es rara. REVISAR.
# Puntos de Mejora - Pendiente
- Seleccionar formato con una opción (opcional), por defecto español.
    - `-en`: Formato inglés con coma (,) como separador de campos y punto (.) como separador decimal
    - `-es`: Formato español con punto (;) como separador de campos y coma (,) como separador decimal
- Sacar mayúsculas en texto común

# Documentación de los comandos utilizados
## Puntuación
- Punto final o signo de cierre: `sed -E 's/(¿[^?]*)$/\1?/; s/(¡[^!]*)$/\1!/; s/([^.?!])$/\1./'`
- Espacio despues de signos: `sed -E 's/([.,;:?!])([^ ])/\1 \2/g'`
- Espacio antes de signos: `sed -E 's/ +([.,;:?!])/\1/g'`
## Mayúsculas
- Primer letra mayuscula: `sed -E 's/^([^a-zA-Z]*)([a-z])/\1\U\2/'`
- Mayuscula despues de signos: `sed -E 's/([.?!] *[¿¡]*)([a-z])/\1\U\2/g'`
- Pronombre yo a Yo: `sed -E 's/\byo\b/Yo/g'`

## Signos de interrogación y exclamación
- Cierre de signos de apertura: 
    - `sed -E ':a; s/(^|[!.,;:?] +)([^¡!.,;:¿?]*\?)/\1¿\2/ ; ta'`
    - `sed -E ':a; s/(^|[!.,;:?] +)([^¡!.,;:¿?]*!)/\1¡\2/ ; ta`
- Cierre de signos  de cierre:
    - `sed -E 's/(¿[^?.,!:;]*)($|[.,;:!])/\1?/g'`
    - `sed -E 's/(¡[^?.,!:;]*)($|[.,;:?])/\1!/g'`
## Espaciado y formato
- Reemplazar +1 espacios seguidos: `sed -E 's/ +/ /g'`
- Eliminar espacios al inicio y al final de cada línea (trim): `sed -E 's/^ +//g; s/ +$//g'`
- Quitar espacios despues de aperturas: `sed -E 's/([¿¡]) +/\1/g'`

## Normalización de caracteres
- Correccion comillas: `sed -E 's/'\''/\"/g'`
- Correcion puntos suspensivos: `sed -E 's/(\.{2,})/\.\.\./g'`