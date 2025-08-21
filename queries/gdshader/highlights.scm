;; ===========================
;; Godot Shader (GDShader) Highlights
;; Extended: multi-line comments + preprocessor
;; ===========================

;; --- Shader types ---
((identifier) @type
  (#match? @type "^(spatial|canvas_item|particles|sky)$"))

;; --- Shader stages ---
((identifier) @keyword
  (#match? @keyword "^(vertex|fragment|light|start)$"))

;; --- Built-in functions ---
((identifier) @function.builtin
  (#match? @function.builtin
    "^(abs|acos|asin|atan|ceil|clamp|cos|cross|cross2d|distance|dot|exp|floor|fract|inverse|length|lerp|max|min|normalize|pow|reflect|refract|round|sign|sin|sqrt|step|tan|transpose)$"))

;; --- Godot-specific built-in functions ---
((identifier) @function.builtin
  (#match? @function.builtin
    "^(NODE_POSITION_WORLD|VIEWPORT_SIZE|VIEWPORT_TEXTURE|INV_CAMERA_MATRIX|CAMERA_MATRIX|NODE_MATRIX|NODE_MATRIX_INVERSE|WORLD_MATRIX|WORLD_MATRIX_INVERSE|CAMERA_DIRECTION|SCREEN_TEXTURE|TIME)$"))

;; --- Built-in constants / vars ---
((identifier) @constant.builtin
  (#match? @constant.builtin
    "^(TIME|PI|TAU|E|FRAGCOORD|VERTEX|NORMAL|UV|UV2|COLOR|INSTANCE_ID|POINT_COORD|SCREEN_UV|SCREEN_PIXEL_SIZE|FRONT_FACING)$"))

;; --- Keywords ---
((identifier) @keyword
  (#match? @keyword "^(uniform|varying|const|if|else|elif|for|while|break|continue|return|discard|void|in|out|inout)$"))

;; --- Types ---
((identifier) @type
  (#match? @type "^(bool|int|float|vec2|vec3|vec4|mat3|mat4|sampler2D|samplerCube)$"))

;; --- Operators ---
((operator) @operator
  (#match? @operator "^[+\\-*/%=!<>&|^~]+$"))

;; --- Numbers ---
((number) @number
  (#match? @number "^[0-9]+(\\.[0-9]+)?$"))

;; --- Single-line comments ---
((comment) @comment
  (#match? @comment "^//.*$"))

;; --- Multi-line comments ---
((comment) @comment
  (#match? @comment "^/\\*.*\\*/$"))

;; --- Preprocessor / directives ---
((preproc) @keyword
  (#match? @preproc "^#(version|ifdef|ifndef|else|elif|endif|define|undef|extension|error|pragma)$"))
