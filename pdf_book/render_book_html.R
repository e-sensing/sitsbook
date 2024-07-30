# 
bookdown::render_book(
    new_session = TRUE,
    config_file = "_bookdown.yml",
    output_format = bookdown::bs4_book(
        df_print = "tibble",
        theme = bookdown::bs4_book_theme(
            base_font = sass::font_google(
                "IBM Plex Serif",
                wght = c(300, 400, 600)
            ),
            code_font = sass::font_google("IBM Plex Mono")
        ),
    )
)
