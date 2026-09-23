[
  %{
    "createSurface" => %{
      "catalogId" => "https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json",
      "surfaceId" => "minimal_standalone"
    },
    "version" => "v0.9.1"
  },
  %{
    "updateComponents" => %{
      "components" => [
        %{
          "children" => ["table_heading", "records_list", "empty_state",
           "status_text", "action_result_panel"],
          "component" => "Column",
          "id" => "root"
        },
        %{
          "component" => "Text",
          "id" => "table_heading",
          "text" => "Minimal",
          "variant" => "h2"
        },
        %{
          "children" => %{"componentId" => "record_row", "path" => "/records"},
          "component" => "List",
          "id" => "records_list"
        },
        %{
          "child" => "record_row_content",
          "component" => "Card",
          "id" => "record_row"
        },
        %{
          "children" => ["table_cell_name", "view_button"],
          "component" => "Row",
          "id" => "record_row_content"
        },
        %{
          "children" => ["table_cell_name_label", "table_cell_name_value"],
          "component" => "Row",
          "id" => "table_cell_name"
        },
        %{
          "component" => "Text",
          "id" => "table_cell_name_label",
          "text" => "Name",
          "variant" => "caption"
        },
        %{
          "component" => "Text",
          "id" => "table_cell_name_value",
          "text" => %{"path" => "name"}
        },
        %{
          "action" => %{
            "event" => %{
              "context" => %{
                "component" => "table",
                "recordId" => %{"path" => "id"}
              },
              "name" => "view_record"
            }
          },
          "child" => "view_button_text",
          "component" => "Button",
          "id" => "view_button"
        },
        %{"component" => "Text", "id" => "view_button_text", "text" => "View"},
        %{
          "children" => %{
            "componentId" => "empty_state_text",
            "path" => "/_empty_visible"
          },
          "component" => "List",
          "id" => "empty_state"
        },
        %{
          "component" => "Text",
          "id" => "empty_state_text",
          "text" => %{"path" => "_empty_message"}
        },
        %{
          "component" => "Text",
          "id" => "status_text",
          "text" => %{"path" => "/ui/feedback/message"}
        },
        %{
          "children" => ["action_result_text"],
          "component" => "Column",
          "id" => "action_result_panel"
        },
        %{
          "component" => "Text",
          "id" => "action_result_text",
          "text" => %{"path" => "/ui/action_result_text"}
        }
      ],
      "surfaceId" => "minimal_standalone"
    },
    "version" => "v0.9.1"
  },
  %{
    "updateDataModel" => %{
      "path" => "/",
      "surfaceId" => "minimal_standalone",
      "value" => %{
        "_empty_message" => "No Minimal records yet.",
        "_empty_visible" => [],
        "errors" => %{},
        "form" => %{},
        "options" => %{},
        "records" => [
          %{
            "id" => "681214b4-e6b5-46f5-8b58-897f77c864ba",
            "name" => "Grace Hopper"
          },
          %{
            "id" => "6b9ba490-c3e9-4585-9111-719af5e4e13f",
            "name" => "Ada Lovelace"
          }
        ],
        "ui" => %{
          "action_result" => %{},
          "action_result_text" => "",
          "feedback" => %{"kind" => nil, "message" => ""},
          "intent" => "browse",
          "panel" => %{
            "mode" => nil,
            "primary_label" => "",
            "record_id" => nil,
            "submit_visible" => [],
            "title" => "",
            "visible" => []
          },
          "status" => ""
        }
      }
    },
    "version" => "v0.9.1"
  }
]