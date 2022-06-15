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

# 
bookdown::render_book(
    output_format = rmarkdown::github_document(
        toc = TRUE,
        df_print = "kable"
    )
)

