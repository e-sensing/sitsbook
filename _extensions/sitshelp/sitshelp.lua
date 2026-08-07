local function ensureHtmlDeps()
  quarto.doc.add_html_dependency({
    name = "sitshelp",
    version = "0.1.0",
    stylesheets = { "assets/sitshelp.css" },
    scripts = { "assets/sitshelp.js" },
  })
end

local function injectConfig(meta)
  local apiUrl = "https://sits-rag.ngrok.io"

  if meta["sitshelp-api-url"] then
    apiUrl = pandoc.utils.stringify(meta["sitshelp-api-url"])
  end

  local config = string.format('apiUrl: "%s"', apiUrl)

  local script = string.format(
    '<script>window.__SITSHELP_CONFIG__ = { %s };</script>',
    config
  )

  quarto.doc.include_text("before-body", script)
end

function Meta(meta)
  ensureHtmlDeps()
  injectConfig(meta)
  return meta
end
