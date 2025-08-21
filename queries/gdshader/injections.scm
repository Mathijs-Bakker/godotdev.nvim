;; ===========================
;; GDShader Injections
;; ===========================

;; Highlight expressions inside parentheses as code
((call_expression
  function: (identifier) @function
  arguments: (argument_list) @parameter))

;; Highlight numbers inside function calls
((number) @number
  (#match? @number "^[0-9]+(\\.[0-9]+)?$"))

;; Highlight vector constructors like vec2, vec3, vec4
((identifier) @type
  (#match? @type "^(vec2|vec3|vec4|mat3|mat4)$"))

;; Highlight boolean literals inside expressions
((true) @boolean)
((false) @boolean)
