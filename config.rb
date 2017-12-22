###
# Page options, layouts, aliases and proxies
###

# Per-page layout changes:
#
# With no layout
page '/*.xml', layout: false
page '/*.json', layout: false
page '/*.txt', layout: false

# General configuration
activate :syntax

# Reload the browser automatically whenever files change
configure :development do
  activate :livereload
end

# Load data
activate :data_source do |c|
  c.root = "#{ENV['CDN_URL']}/data"
  c.files = [
    "authors.json",
    "links.json"
  ]
end

# Use sprockets for asset compilation
activate :sprockets
sprockets.append_path File.join(root, 'vendor', 'node_components')

# Set markdown template engine
set :markdown_engine, :pandoc
set :markdown, smartypants: true,
               metadata: "link-citations",
               csl: "styles/apa.csl",
               bibliography: "data/references.yaml",
               lang: "en"

# put configuration variables into .env file
activate :dotenv

# use asset host
# activate :asset_host, host: ENV['CDN_URL']

###
# Helpers
###

# Methods defined in the helpers block are available in templates
helpers do
  def stage?
    ENV['RACK_ENV'] == "stage"
  end

  def sanitize(string)
    Sanitize.fragment(string).squish
  end

  def author_string(author)
    Array(author).map { |a| data.authors.fetch(a, {})[:name] }.to_sentence
  end

  def article_as_json(article)
    type = article.data.type.presence || "BlogPosting"
    url = data.site.url + article.url
    id = article.data.doi.present? ? "https://doi.org/" + article.data.doi : url
    version = article.data.version.presence || "1.0"
    keywords = article.data.tags.present? ? article.data.tags.join(", ") : nil
    license = data.site.license.url || "https://creativecommons.org/licenses/by/4.0/"
    date_created = article.data.date_created.presence || article.data.date
    date_published = article.data.published.to_s == "false" ? nil : article.data.date

    publisher = data.site.publisher.presence
    if publisher
      publisher = {
        "@type" => "Organization",
        "name" => publisher }
    end

    spatial_coverage = article.data.location.presence
    if spatial_coverage
      location = article.data.location.split(", ", 3)
      locality = location.first
      region = location.length > 2 ? location.second : nil
      country = location.length > 1 ? location.last : nil

      spatial_coverage = {
        "@type" => "PostalAddress",
        "addressLocality" => locality,
        "addressRegion" => region,
        "addressCountry" => country }.compact
    end

    author = Array(article.data.author).map do |a|
      au = data.authors.fetch(a, {})
      { "@type" => au[:type] || "Person",
        "@id" => au[:orcid],
        "givenName" => au[:given],
        "familyName" => au[:family],
        "name" => au[:name] }.compact
    end

    html = article.render({layout: false})
    doc = Nokogiri::HTML(html)

    if type == "BlogPosting"
      description = Bergamasco::Summarize.summary_from_html(html)
      date_modified = article.data.date_modified.presence || article.data.date
      is_part_of = {
        "@type" => "Blog",
        "@id" => "https://doi.org/" + data.site.doi,
        "name" => data.site.title }
      has_part = nil
      xmlname = File.basename(article.path, '.html') + ".xml"

      encoding = {
        "@type" => "MediaObject",
        "@id" => data.site.url + "/" + File.basename(article.path, '.html') + "/" + xmlname,
        "fileFormat" => "application/xml"
      }
    else
      description = data.site.description
      date_modified = blog.articles.map { |a| a.date }.max.to_date.iso8601
      is_part_of = nil
      encoding = nil
      has_part = articles_published.map do |a|
        aurl = data.site.url + a.url
        aid = a.data.doi.present? ? "https://doi.org/" + a.data.doi : aurl
        date_created = a.data.date_created.presence || a.data.date
        date_published = a.data.published ? a.data.date : nil

        { "@type" => "BlogPosting",
          "@id" => aid,
          "name" => a.data.title,
          "dateCreated" => date_created,
          "datePublished" => date_published }.compact
      end
    end

    # expects a references list generated by pandoc
    citation = doc.xpath('//div[@id="refs"]/div/@id').map do |ref|
      { "@type" => "CreativeWork",
        "@id" => ref.value[4..-1] }
    end

    { "@context" => "http://schema.org",
      "@type" => type,
      "@id" => id,
      "name" => article.data.title,
      "alternateName" => article.data.accession_number.presence,
      "url" => url,
      "author" => author,
      "publisher" => publisher,
      "dateCreated" => date_created,
      "datePublished" => date_published,
      "dateModified" => date_modified,
      "spatialCoverage" => spatial_coverage,
      "keywords" => keywords,
      "version" => version,
      "description" => description,
      "license" => license,
      "image" => article.data.image.presence,
      "encoding" => encoding,
      "isPartOf" => is_part_of,
      "hasPart" => has_part,
      "citation" => citation.presence
    }.compact.to_json
  end

  def page_title(page)
    page.data.title
  end

  def page_image(page)
    return "/images/datacite.png" if page.nil? || page.data.image.nil?

    page.data.image
  end

  def page_description(page)
    return ENV['SITE_DESCRIPTION'] if page.nil? || page.data.doi.nil?

    html = page.render({layout: false})
    Bergamasco::Summarize.summary_from_html(html)
  end

  def articles_published
    blog.articles.select { |a| a.data.published.to_s != "false" }.sort_by { |a| a.data.date.to_date.iso8601 }.reverse
  end
end

activate :blog do |blog|
  blog.sources = "posts/{title}.html"
  blog.permalink = "{title}"
end

activate :directory_indexes

page "/feed.xml", layout: false

# Build-specific configuration
configure :build do
  # Minify CSS on build
  activate :minify_css

  # Minify Javascript on build
  activate :minify_javascript
end

# ready do
#   resources_without_accession_number = sitemap.resources.select { |r| r.data.accession_number.blank? }
#   namespace = 'MS-'
#   upper_limit = 1000000

#   resources_without_accession_number.each do |resource|
#     number = SecureRandom.random_number(upper_limit).to_s
#     resource.add_metadata accession_number: namespace + number
#   end

#   resources
# end
