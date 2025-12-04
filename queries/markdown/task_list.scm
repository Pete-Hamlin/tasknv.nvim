; match headings
(atx_heading
  (atx_h1_marker) @heading
  (#set! heading_level 1)
)
(atx_heading
  (atx_h2_marker) @heading
  (#set! heading_level 2)
)
(atx_heading
  (atx_h3_marker) @heading
  (#set! heading_level 3)
)

; match list items that are markdown checkboxes
(list_item
  (task_list_marker_unchecked) @unchecked
  (paragraph (inline) @task_text)?
)

(list_item
  (task_list_marker_checked) @checked
  (paragraph (inline) @task_text)?
)

