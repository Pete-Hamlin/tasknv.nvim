
(section
    ;; headings
    (atx_heading
      (inline) @heading_text 
    )
    ;; task list items
    (list
         (list_item
            (list_marker_star)
            [
                (task_list_marker_unchecked) @unchecked
                (task_list_marker_checked) @checked
            ] @task_status
            (paragraph) @task_text
            (list)? @subtask_list
        ) @task_item
    ) @task_list
)
