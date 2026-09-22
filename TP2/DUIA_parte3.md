# DUIA — Parte 3: Lectura Crítica

| Campo | Completar |
|---|---|
| **Herramienta** | OpenCode (big-pickle) |
| **Spec o prompt utilizado** | "Analizá estos dos scripts y decime qué harían realmente, por qué no coinciden con la consigna, y cómo se corregirían: Script 1 (UPDATE funcion SET activa = FALSE) y Script 2 (DELETE FROM categoria WHERE id NOT IN (SELECT categoria_id FROM producto))." |
| **Qué generó** | Archivo `ejercicio_lectura_critica.md` con análisis de ambos scripts: qué hacen realmente, por qué no cumplen la consigna, y versión corregida de cada uno. |
| **Qué se aceptó** | El análisis de ambos scripts se aceptó tal cual. |
| **Qué se modificó o descartó, y por qué** | No se modificó nada. |
| **Verificación realizada** | Se verificó en PostgreSQL que `NOT IN` con subconsulta que contiene `NULL` no funciona como se espera, confirmando el defecto identificado en el Script 2. |
