bookdown::render_book(
    new_session = FALSE,
    config_file = "_bookdown.yml",
    output_format =  rmarkdown::pdf_document(
        toc = TRUE,
        dev = "cairo_pdf",
        latex_engine = "xelatex",
        df_print = "tibble",
        keep_tex = TRUE,
        pandoc_args = "--listings",
        includes = rmarkdown::includes(
            in_header = "latex/preamble.tex", 
            before_body = "latex/before_body.tex", 
            after_body = "latex/after_body.tex")
    )
)

rmarkdown::render_site("./docs/", 
                       output_format = 'bookdown::pdf_book', 
                       encoding = 'UTF-8')

# 
bookdown::render_book(
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

