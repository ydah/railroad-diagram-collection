# Railroad Diagram Collection 作業手順書

現在のコマンド・検証方法は [CONTRIBUTING.md](../CONTRIBUTING.md) と [IMPLEMENTATION.md](./IMPLEMENTATION.md) を参照。以下のコード例は着手時の案として保存している。

- 対応文書: [ROADMAP.md](./ROADMAP.md) / [DESIGN.md](./DESIGN.md)
- 版: v1（2026-09-30）
- 検証環境: Ruby 3.2 / Lrama 0.8.0 / railroad_diagrams / Nokogiri 1.19 / Git 2.43 / Chromium（Playwright）
- ✅ の付いたコード・コマンドは実行して動作を確認済み。それ以外は雛形なので、初回実行時に確認すること。

---

## 0. 共通事項

### 0.1 前提環境

| ツール | バージョン | 用途 |
|---|---|---|
| Git | 2.35 以上（`sparse-checkout set --no-cone`） | 文法ソースの取得 |
| Ruby / Bundler | 3.3 以上 / 2.5 以上 | ビルド |
| Node.js | 20 以上 | CI の検査ツール（html-validate、Playwright、Lighthouse CI） |
| GNU Bison | 任意 | `bison_report` フロントエンド（Phase 3） |

### 0.2 ブランチと PR

- `main` は保護する（CI 必須・レビュー 1 名）。
- ブランチ名は `<type>/<ID>-<要約>` とする（例: `fix/B-04-diagram-scroll`、`feat/U-01-toc`）。
- 原則として 1 PR = 1 ID とする。PR タイトルは `[B-04] …`、本文に ROADMAP の ID と完了条件のチェックリストを書く。
- コミットメッセージは Conventional Commits に従う。

### 0.3 共通の完了定義（DoD）

1. CI がすべて成功している。
2. タスクの完了条件をすべて満たしている。
3. UI を変えた場合は、変更前後のスクリーンショットを PR に貼っている。
4. `CHANGELOG.md` と関連ドキュメントを更新している。

### 0.4 Issue の一括起票

```bash
# 1) ラベルを作成
for l in phase:0 phase:1 phase:2 phase:3 phase:4 phase:5 type:bug type:feature type:infra \
         priority:P0 priority:P1 priority:P2 priority:P3 upstream; do
  gh label create "$l" --force
done

# 2) issues.tsv（ID<TAB>タイトル<TAB>ラベル）から起票
while IFS=$'\t' read -r id title labels; do
  gh issue create --title "[$id] $title" --label "$labels" \
    --body "詳細は docs/ROADMAP.md の $id を参照。"
done < issues.tsv
```

---

## 1. Phase 0 — 応急処置（〜3 日）

### T0-1 ライセンスファイル（B-02）

1. `git switch -c fix/B-02-license`
2. `git mv MIT LICENSE`
3. README の License 節のリンク先を `LICENSE` に直す。
4. PR を作ってマージする。

**完了条件**: リポジトリの About 欄に「MIT license」と表示される。

### T0-2 トップページ（B-01, B-12）

`index.html` の `<head>` に次を追加・修正する。

```html
<meta name="description" content="Railroad diagrams (syntax diagrams) for Ruby, PHP and Perl, generated from their parser grammars.">
<link rel="canonical" href="https://ydah.github.io/railroad-diagram-collection/">
<meta property="og:url" content="https://ydah.github.io/railroad-diagram-collection/">
<meta property="og:image" content="https://ydah.github.io/railroad-diagram-collection/assets/ogp.png">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card" content="summary_large_image">
```

- カード見出しを `<h2>` から `<h3>` に変え、CSS の `.language-card h2` も `h3` に合わせる。
- フッターに GitHub へのリンクを追加し、年表記を「© 2025–」にする。

**確認**: `curl -s https://ydah.github.io/railroad-diagram-collection/ | grep -E 'og:|twitter:'` で出力を確認し、各 SNS のカードプレビューで画像が表示されることを確かめる。

### T0-3 言語ページへのパッチ ✅（B-03, B-04, B-05, B-07, B-10, B-11）

`scripts/patch_legacy_pages.rb` を追加して実行する。何度実行しても結果が変わらない（冪等）。Phase 1 でパイプラインに置き換えたら削除する。

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Phase 0 応急パッチ: Lrama が生成した言語ページに最低限の修正を適用する。
# 冪等（何度実行しても結果は同じ）。Phase 1 で生成パイプラインに置き換えたら削除する。
#
#   ruby scripts/patch_legacy_pages.rb
require "cgi"

MARKER   = "<!-- rdc:legacy-patch v1 -->"
PAGES    = { "ruby.html" => "Ruby", "php.html" => "PHP", "perl.html" => "Perl" }.freeze
REPO_URL = "https://github.com/ydah/railroad-diagram-collection"

# 規則名 → 安定 ID（DESIGN.md「7. URL 設計と ID 規約」と同一の規則）
def slug(name)
  "r-" + name.b.gsub(/[^A-Za-z0-9_]/) { |c| format("~%02X", c.ord) }
end

EXTRA_CSS = <<~CSS
  body { margin: 0; padding: 0 12px 48px; text-align: center; }
  .site-nav { text-align: left; padding: 12px 0; margin-bottom: 16px; border-bottom: 1px solid #ddd; }
  .diagram-scroll { overflow-x: auto; margin: 0 auto 24px; }
  .diagram-scroll > svg { display: block; margin: 0 auto; }
  h2.diagram-header { scroll-margin-top: 8px; }
  h2.diagram-header a { color: inherit; text-decoration: none; }
CSS

def must!(result, what, file)
  result or abort("#{file}: #{what} が見つかりません（テンプレートが想定と異なる）")
end

Dir.chdir(File.expand_path("..", __dir__)) do
  PAGES.each do |file, lang|
    html = File.read(file, encoding: "UTF-8")
    if html.include?(MARKER)
      puts "skip:    #{file}（適用済み）"
      next
    end

    # B-03: lang / charset / viewport / description
    must! html.sub!("<html>", %(<html lang="en">)), "<html>", file
    must! html.sub!("<head>", <<~HEAD.chomp), "<head>", file
      <head>
        #{MARKER}
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="description" content="#{lang} railroad diagrams (syntax diagrams) generated from the #{lang} parser grammar.">
    HEAD

    # B-05: 無効な CSS 値
    must! html.gsub!("stroke: 5;", "stroke-width: 5;"), "stroke: 5;", file

    # B-04: svg { width: 100% } を撤廃し、横スクロール枠で原寸表示
    must! html.sub!(/^\s*svg \{\s*width: 100%;\s*\}\n/, ""), "svg { width: 100% }", file
    must! html.sub!("</style>", "#{EXTRA_CSS}</style>"), "</style>", file
    must! html.gsub!(%r{<svg class="railroad-diagram".*?</svg>}m) { %(<div class="diagram-scroll">#{Regexp.last_match(0)}</div>) },
          "svg.railroad-diagram", file

    # B-07: 見出しに安定 ID とパーマリンク
    must! html.gsub!(%r{<h2 class="diagram-header">(.*?)</h2>}) {
      label = Regexp.last_match(1)
      id = slug(CGI.unescapeHTML(label))
      %(<h2 class="diagram-header" id="#{id}"><a href="##{id}">#{label}</a></h2>)
    }, "h2.diagram-header", file

    # B-07: 非終端記号クリックで URL を更新し、ブラウザの「戻る」を効かせる
    must! html.sub!('targetHeader.scrollIntoView({ behavior: "smooth", block: "start" });',
                    "location.hash = targetHeader.id;"), "scrollIntoView 呼び出し", file

    # B-10 / B-11: 廃止属性の除去と、トップ・GitHub への導線
    nav = %(<nav class="site-nav" aria-label="Site"><a href="./">&larr; All languages</a> &middot; <a href="#{REPO_URL}">GitHub</a></nav>)
    must! html.sub!(%(<body align="center">), "<body>\n#{nav}"), "<body align=\"center\">", file

    File.write(file, html)
    puts "patched: #{file}"
  end
end
```

**手順** ✅

```bash
ruby scripts/patch_legacy_pages.rb   # patched: ruby.html / php.html / perl.html
ruby scripts/patch_legacy_pages.rb   # 2 回目は全ページ skip（冪等性の確認）
grep -o 'id="r-[^"]*"' ruby.html | wc -l            # 303
grep -o 'id="r-[^"]*"' ruby.html | sort -u | wc -l  # 303（重複なし）
python3 -m http.server 8000                         # ローカルで確認
```

**完了条件**（検証済みの値）:

- 規則 ID の数が Ruby 303 / PHP 186 / Perl 113 で、重複がない。
- 幅 375px のモバイル表示で、PHP の最大幅の図（1784.5px）が原寸のまま 351px 幅の枠内で横スクロールでき、ページ全体は横にスクロールしない。
- 非終端記号をクリックすると URL が `#r-…` に変わり、「戻る」で元の位置に戻る。
- `ruby.html#r-option_~27~5Cn~27` のようなディープリンクを開くと、該当する規則へ移動する。

### T0-4 README 更新（B-13, C-04）

1. 構成図を実ファイル（`assets/`、`LICENSE`）に合わせる。
2. 「生成方法」節を追加する。現状は Lrama の構文図出力であり、Phase 1 以降は `rdc build` で生成する旨を書く。
3. Future Plans に、Python / JavaScript / Go は Yacc 系文法ではないため、別形式のフロントエンド（C-02）が前提であることを明記する。
4. `docs/` の 3 文書へのリンクを追加する。

### T0-5 リポジトリ衛生（O-05, O-09）

1. 次のファイルを追加する。
   - `CONTRIBUTING.md`: 開発環境、ビルド、言語追加の流れ（T5-1 へのリンク）
   - `.github/pull_request_template.md`: ROADMAP の ID、完了条件のチェックリスト、スクリーンショット欄
   - `.github/ISSUE_TEMPLATE/bug_report.yml`、`language_request.yml`（文法ファイルの URL とライセンスの欄を必須にする）
   - `CHANGELOG.md`、`.editorconfig`
2. README に「Sources & Licenses」節を追加する。各文法の出典を記載し、ライセンスは確認のうえ記入する。

### T0-6 上流 Lrama への起票（L-01, L-02, L-05）

| 件名 | 再現手順 | 期待する結果 |
|---|---|---|
| L-01: テンプレートの `stroke: 5`、viewport なし、`svg { width: 100% }` | `lrama --diagram=out.html <任意の文法>` を実行し、モバイルで開く | `stroke-width` になり、viewport があり、原寸で横スクロールできる |
| L-02: 終端記号の二重エスケープ | Ruby の parse.y から生成すると `'\n'` が `'\\n'` と表示される | `'\n'` と表示される |
| L-05: 規則名とコロンの間のコメントで構文エラー | Perl v5.44.0 の `perly.y` を入力すると 331 行目で `parse error on value 'bare_statement_expression'` | Bison と同様に受理される |

### T0-7 v0.1 リリース

1. デプロイ後、実機またはエミュレーションで T0-3 の完了条件を再確認する。
2. `git tag v0.1.0` を打ち、`CHANGELOG.md` を更新する。

---

## 2. Phase 1 — 再現可能なビルド基盤（1〜2 週）

### T1-1 Ruby プロジェクトの雛形 ✅

```bash
mkdir -p exe lib/rdc/frontends lib/rdc/site lib/rdc/templates grammars/perl site/assets/css site/assets/js test
```

`Gemfile`:

```ruby
# frozen_string_literal: true
source "https://rubygems.org"

gem "lrama", "~> 0.8.0"
gem "railroad_diagrams"   # lrama --diagram に必要（lrama の依存には含まれない）
gem "nokogiri"
gem "rake"

group :test do
  gem "minitest"
end
```

`exe/rdc`:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative "../lib/rdc/cli"
Rdc::CLI.start(ARGV)
```

`lib/rdc/cli.rb`:

```ruby
# frozen_string_literal: true
require "optparse"
require_relative "manifest"
require_relative "fetcher"

module Rdc
  module CLI
    USAGE = "usage: rdc {fetch|build|serve} [lang[@version]] [options]"

    module_function

    def start(argv)
      command = argv.shift
      opts = { out: "dist", port: 8000 }
      OptionParser.new do |o|
        o.on("--out DIR") { |v| opts[:out] = v }
        o.on("--port N", Integer) { |v| opts[:port] = v }
      end.parse!(argv)
      filter = argv.first
      manifest = Manifest.load

      case command
      when "fetch"
        manifest.each_version(filter) do |lang, ver|
          r = Fetcher.new.fetch(lang, ver)
          puts "#{lang.id}@#{ver.id}: #{ver.ref} #{r.commit[0, 7]}"
        end
      when "build"
        require_relative "site/builder"
        Site::Builder.new(manifest, out: opts[:out], filter: filter).build
      when "serve"
        exec("ruby", "-run", "-e", "httpd", opts[:out], "-p", opts[:port].to_s) # 要 webrick gem
      else
        abort USAGE
      end
    end
  end
end
```

### T1-2 manifest と前処理 ✅（B-14）

1. 最新の安定タグを確認する。

   ```bash
   git ls-remote --tags --refs https://github.com/php/php-src.git 'php-8.5.*'
   git ls-remote --tags --refs https://github.com/ruby/ruby.git 'v4.*'        # 4.0 以降は v4.0.0 形式
   git ls-remote --tags --refs https://github.com/Perl/perl5.git 'v5.4*'
   ```

2. `grammars/manifest.yml` を書く。完全版は DESIGN.md の 5.1 節にあり、次は動作確認済みの最小版。

   ```yaml
   schema: 1
   languages:
     php:
       name: PHP
       frontend: lrama
       repo: https://github.com/php/php-src.git
       grammar: Zend/zend_language_parser.y
       sparse: [/Zend/zend_language_parser.y]
       versions:
         - { id: "8.5", ref: "php-8.5.0", default: true }
     perl:
       name: Perl
       frontend: lrama
       repo: https://github.com/Perl/perl5.git
       grammar: perly.y
       sparse: [/perly.y]
       preprocess: "ruby %{rdc_root}/grammars/perl/strip_rule_comments.rb perly.y"
       versions:
         - { id: "5.44", ref: "v5.44.0", default: true }
     ruby:
       name: Ruby
       frontend: lrama
       repo: https://github.com/ruby/ruby.git
       grammar: parse.y
       sparse: [/parse.y, /tool/id2token.rb, /defs/id.def]
       preprocess: "ruby tool/id2token.rb parse.y"
       versions:
         - { id: "4.0", ref: "v4.0.0", default: true }
   ```

3. Perl 用の前処理 `grammars/perl/strip_rule_comments.rb` を追加する（L-05 が上流で直るまでの回避策）。

   ```ruby
   # frozen_string_literal: true
   # Lrama が「規則名とコロンの間のコメント」を解析できない問題（L-05）の回避。
   # 規則名だけの行の直後にあるコメント行を取り除き、標準出力に書き出す。
   src = File.read(ARGV.fetch(0))
   print src.gsub(%r{^(\w+)\n[ \t]*/\*.*?\*/[ \t]*\n}m) { "#{Regexp.last_match(1)}\n" }
   ```

`lib/rdc/manifest.rb`:

```ruby
# frozen_string_literal: true
require "yaml"

module Rdc
  Version  = Struct.new(:id, :ref, :default, keyword_init: true)
  Language = Struct.new(:id, :name, :frontend, :repo, :grammar, :sparse, :preprocess, :start,
                        :tag_pattern, :notes, :versions, keyword_init: true)

  class Manifest
    PATH = File.expand_path("../../grammars/manifest.yml", __dir__)

    def self.load(path = PATH)
      data = YAML.safe_load_file(path)
      raise "unsupported manifest schema" unless data["schema"] == 1

      langs = data.fetch("languages").map do |id, h|
        versions = h.fetch("versions").map { |v| Version.new(**v.transform_keys(&:to_sym)) }
        Language.new(id: id, **h.except("versions").transform_keys(&:to_sym), versions: versions)
      end
      new(langs)
    end

    attr_reader :languages

    def initialize(languages) = @languages = languages

    # filter: nil / "php" / "php@8.5"
    def each_version(filter = nil)
      lang_id, ver_id = filter&.split("@", 2)
      languages.each do |lang|
        next if lang_id && lang.id != lang_id

        lang.versions.each do |ver|
          next if ver_id && ver.id != ver_id

          yield lang, ver
        end
      end
    end
  end
end
```

### T1-3 取得処理（fetcher） ✅（O-01）

`lib/rdc/fetcher.rb`:

```ruby
# frozen_string_literal: true
require "digest"
require "fileutils"
require "open3"
require "shellwords"

module Rdc
  # 文法ソースをタグ固定で取得し、必要なら前処理して「Lrama に渡す文法」を用意する
  class Fetcher
    ROOT  = File.expand_path("../..", __dir__)
    CACHE = File.join(ROOT, ".cache", "src")

    Result = Struct.new(:dir, :grammar_path, :display_name, :commit, :sha256, keyword_init: true)

    def fetch(lang, ver)
      dir = File.join(CACHE, lang.id, ver.id)
      unless File.directory?(File.join(dir, ".git"))
        FileUtils.mkdir_p(File.dirname(dir))
        run!("git", "-c", "advice.detachedHead=false", "clone", "--quiet", "--depth", "1",
             "--branch", ver.ref, "--filter=blob:none", "--sparse", lang.repo, dir)
        run!("git", "-C", dir, "sparse-checkout", "set", "--no-cone", *lang.sparse)
      end
      grammar = File.join(dir, lang.grammar)
      Result.new(dir: dir, grammar_path: preprocess(lang, dir, grammar),
                 display_name: File.basename(lang.grammar),
                 commit: capture!("git", "-C", dir, "rev-parse", "HEAD").strip,
                 sha256: Digest::SHA256.file(grammar).hexdigest)
    end

    private

    def preprocess(lang, dir, grammar)
      return grammar unless lang.preprocess

      out = File.join(dir, ".rdc", "grammar.y")
      FileUtils.mkdir_p(File.dirname(out))
      cmd = format(lang.preprocess, rdc_root: ROOT)
      File.write(out, capture!(*Shellwords.split(cmd), chdir: dir))
      out
    end

    def run!(*cmd, **opts)
      system(*cmd, exception: true, **opts)
    end

    def capture!(*cmd, **opts)
      out, err, status = Open3.capture3(*cmd, **opts)
      raise "#{cmd.join(' ')} failed: #{err}" unless status.success?

      out
    end
  end
end
```

**確認** ✅: `bundle exec exe/rdc fetch` を実行すると次のように表示される。

```
php@8.5: php-8.5.0 685e996
perl@5.44: v5.44.0 e634cc8
ruby@4.0: v4.0.0 553f167
```

作業の最後に `grammars/lock.yml` へコミット SHA と sha256 を書き出す処理を追加する。

### T1-4 Lrama による生成 ✅

手動で試すときのコマンド:

```bash
# PHP（前処理なし）
lrama --diagram=tmp/php-8.5.html -o tmp/php.tab.c .cache/src/php/8.5/Zend/zend_language_parser.y

# Ruby（Ruby 本体の common.mk と同じく id2token.rb で前処理し、標準入力で渡す）
(cd .cache/src/ruby/4.0 && ruby tool/id2token.rb parse.y) | lrama --diagram=tmp/ruby-4.0.html -o tmp/ruby.tab.c - parse.y
```

- `-o` を指定しないと、カレントディレクトリにパーサ本体（`y.tab.c`）が出力される。
- 検証時の生成結果: PHP 189 規則 / Ruby 305 規則 / Perl 139 規則（見出し数）。

`lib/rdc/generator.rb`:

```ruby
# frozen_string_literal: true
require "fileutils"

module Rdc
  module Generator
    module_function

    def lrama_diagram(fetched, out_html)
      FileUtils.mkdir_p(File.dirname(out_html))
      tab_c = out_html.sub(/\.html\z/, ".tab.c") # パーサ本体も出力されるので置き場所を指定
      # 文法は標準入力で渡し、エラーメッセージ用に元のファイル名を指定する
      system("lrama", "--diagram=#{out_html}", "-o", tab_c, "-", fetched.display_name,
             in: fetched.grammar_path, exception: true)
      out_html
    end
  end
end
```

### T1-5 フロントエンド `lrama_html` ✅

`lib/rdc/frontends/lrama_html.rb`（Nokogiri 1.19 の HTML5 パーサで、SVG 要素にも CSS セレクタでマッチすることを確認済み）:

```ruby
# frozen_string_literal: true
require "nokogiri"

module Rdc
  module Frontends
    class LramaHtml
      Rule = Struct.new(:name, :svg, :refs, :terminals, keyword_init: true)

      def parse(html)
        doc = Nokogiri::HTML5(html)
        doc.css("h2.diagram-header").map do |h2|
          svg = h2.next_element
          raise "svg not found after #{h2.text.inspect}" unless svg&.name == "svg"

          Rule.new(
            name: h2.text,
            svg: svg,
            refs: svg.css("g.non-terminal > text").map(&:text).uniq,
            terminals: svg.css("g.terminal > text").map(&:text).uniq
          )
        end
      end
    end
  end
end
```

**確認** ✅: 現行の 3 ページを入力にすると、Ruby 303 / PHP 186 / Perl 113 規則を取り出せ、未定義参照は 0 件になる。

**B-06（二重エスケープ）**: 取り出した名前は `option_'\\n'` のようにバックスラッシュが 2 つになっている。元の文法と照合したうえで、表示時に 1 つへ補正する処理をここに追加する。

### T1-6 サイトビルダーとテンプレート ✅（U-02, U-03, U-06, U-08, U-12）

`lib/rdc/site/builder.rb`:

```ruby
# frozen_string_literal: true
require "erb"
require "fileutils"
require "json"
require_relative "../slug"
require_relative "../fetcher"
require_relative "../generator"
require_relative "../frontends/lrama_html"

module Rdc
  module Site
    class Builder
      TEMPLATES = File.expand_path("../templates", __dir__)
      ASSETS    = File.expand_path("../../../site/assets", __dir__)
      Page = Struct.new(:lang, :ver, :source, :rules, :used_by, :paths, keyword_init: true)

      def initialize(manifest, out:, filter: nil)
        @manifest, @out, @filter = manifest, out, filter
      end

      def build
        FileUtils.rm_rf(@out)
        FileUtils.mkdir_p(@out)
        FileUtils.cp_r(ASSETS, File.join(@out, "assets"))
        pages = []
        @manifest.each_version(@filter) do |lang, ver|
          page = build_language(lang, ver)
          write("#{lang.id}/#{ver.id}/index.html", render("language", page: page, root: "../../"))
          if ver.default
            write("#{lang.id}/index.html", render("language", page: page, root: "../"))
            write("#{lang.id}.html", render("redirect", target: "#{lang.id}/")) # 旧 URL（O-06）
          end
          pages << page
        end
        write("index.html", render("index", pages: pages, root: ""))
        verify_links!
      end

      private

      def build_language(lang, ver)
        fetched = Fetcher.new.fetch(lang, ver)
        html = Generator.lrama_diagram(fetched, File.join(Fetcher::ROOT, ".cache", "diagram", "#{lang.id}-#{ver.id}.html"))
        rules = Frontends::LramaHtml.new.parse(File.read(html, encoding: "UTF-8"))
        rules.each { |r| link_nonterminals!(r.svg) }
        refs = rules.to_h { |r| [r.name, r.refs] }
        used_by = Hash.new { |h, k| h[k] = [] }
        refs.each { |from, tos| tos.each { |to| used_by[to] << from } }
        start = lang.start || refs.fetch("$accept").first
        Page.new(lang: lang, ver: ver, source: fetched, rules: rules, used_by: used_by,
                 paths: paths_from(start, refs))
      end

      # 非終端記号を SVG 内の実リンクにする（U-03）。
      # HTML として出力し、ブラウザが SVG 名前空間の <a> として解釈する。
      def link_nonterminals!(svg)
        svg.css("g.non-terminal").each do |g|
          name = g.at_css("text").text
          a = svg.document.create_element("a", "href" => "##{Slug.rule(name)}", "class" => "rr-nt",
                                               "aria-label" => "Go to rule #{name}")
          g.add_previous_sibling(a)
          a.add_child(g)
        end
      end

      # 開始記号からの最短参照経路（U-08）
      def paths_from(start, refs)
        parent = { start => nil }
        queue = [start]
        until queue.empty?
          cur = queue.shift
          refs.fetch(cur, []).each do |nxt|
            next if parent.key?(nxt)

            parent[nxt] = cur
            queue << nxt
          end
        end
        parent.keys.to_h do |node|
          path = []
          n = node
          while n
            path.unshift(n)
            n = parent[n]
          end
          [node, path]
        end
      end

      def kind_of(name)
        case name
        when "$accept" then "accept"
        when /\A\$?@\d+\z/ then "midrule"
        else "normal"
        end
      end

      def render(template, **locals)
        src = File.read(File.join(TEMPLATES, "#{template}.html.erb"), encoding: "UTF-8")
        ERB.new(src, trim_mode: "-").result_with_hash(
          locals.merge(h: ->(s) { ERB::Util.html_escape(s) }, slug: Slug, kind_of: method(:kind_of))
        )
      end

      def write(rel, content)
        path = File.join(@out, rel)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content, encoding: "UTF-8")
      end

      # 整合性検査: ページ内リンクの参照先 id が存在し、id が重複しないこと
      def verify_links!
        Dir.glob(File.join(@out, "**/*.html")).each do |file|
          html = File.read(file, encoding: "UTF-8")
          ids = html.scan(/\sid="([^"]+)"/).flatten
          dup = ids.tally.select { |_, n| n > 1 }.keys
          missing = html.scan(/href="#([^"]+)"/).flatten.uniq - ids
          raise "#{file}: duplicate ids #{dup.first(5)}" unless dup.empty?
          raise "#{file}: broken anchors #{missing.first(5)}" unless missing.empty?
        end
      end
    end
  end
end
```

`lib/rdc/slug.rb` は DESIGN.md の 7.2 節のコードをそのまま使う。

`lib/rdc/templates/language.html.erb`:

```erb
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><%= h.(page.lang.name) %> <%= h.(page.ver.id) %> railroad diagrams</title>
  <meta name="description" content="Railroad diagrams (syntax diagrams) of the <%= h.(page.lang.name) %> <%= h.(page.ver.id) %> parser grammar.">
  <link rel="canonical" href="https://ydah.github.io/railroad-diagram-collection/<%= page.lang.id %>/<%= page.ver.id %>/">
  <link rel="stylesheet" href="<%= root %>assets/css/app.css">
  <script type="module" src="<%= root %>assets/js/app.js"></script>
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="site-header"><a href="<%= root %>">Railroad Diagrams</a> / <%= h.(page.lang.name) %> <%= h.(page.ver.id) %></header>
<div class="layout">
<nav class="toc" aria-label="Rules">
  <input type="search" class="toc-filter" placeholder="Filter rules" aria-label="Filter rules">
  <ul>
<% page.rules.each do |r| -%>
    <li data-name="<%= h.(r.name) %>" data-kind="<%= kind_of.(r.name) %>"><a href="#<%= slug.rule(r.name) %>"><%= h.(r.name) %></a></li>
<% end -%>
  </ul>
</nav>
<main id="main">
  <h1><%= h.(page.lang.name) %> <%= h.(page.ver.id) %></h1>
  <p class="source">Source: <%= h.(page.lang.grammar) %> @ <%= h.(page.ver.ref) %> (<%= page.source.commit[0, 7] %>)</p>
<% page.rules.each do |r| id = slug.rule(r.name) -%>
  <section class="rule" id="<%= id %>" data-kind="<%= kind_of.(r.name) %>" style="contain-intrinsic-size: auto <%= r.svg["height"].to_f.ceil + 60 %>px">
    <h2 class="rule-title" id="h-<%= id %>"><a href="#<%= id %>"><%= h.(r.name) %></a></h2>
<% if (path = page.paths[r.name]) && path.size > 1 -%>
    <nav class="rule-path" aria-label="Path from start symbol"><%= path.map { |n| %(<a href="##{slug.rule(n)}">#{h.(n)}</a>) }.join(" › ") %></nav>
<% end -%>
    <div class="diagram-scroll" tabindex="0" role="region" aria-label="Diagram of <%= h.(r.name) %>"><%= r.svg.to_html %></div>
<% unless page.used_by[r.name].empty? -%>
    <details class="rule-usedby"><summary>Used by (<%= page.used_by[r.name].uniq.size %>)</summary>
      <ul><% page.used_by[r.name].uniq.each do |u| %><li><a href="#<%= slug.rule(u) %>"><%= h.(u) %></a></li><% end %></ul>
    </details>
<% end -%>
  </section>
<% end -%>
</main>
</div>
</body>
</html>
```

`lib/rdc/templates/index.html.erb`（最小版。T2-9 で刷新する）:

```erb
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>Railroad Diagrams</title></head>
<body><h1>Programming Language Railroad Diagrams</h1><ul>
<% pages.each do |p| %><li><a href="<%= p.lang.id %>/"><%= h.(p.lang.name) %> <%= h.(p.ver.id) %></a> — <%= p.rules.size %> rules</li><% end %>
</ul></body></html>
```

**注意点**（検証中に遭遇したもの）:

- **文字コード**: `LANG` が未設定の CI では `File.read` が US-ASCII 扱いになり、ERB が失敗する。読み書きには必ず `encoding: "UTF-8"` を付ける。
- **ページサイズ**: Nokogiri は `<path …/>` を `<path …></path>` に展開するため、サイズが増える。Ruby ページの gzip サイズは 現行 58.8 KB → 83.3 KB だった。長さ 0 のパスを除去し自己終了タグに戻すと 65.5 KB になるため、この最適化をビルドに組み込む。

### T1-7 旧 URL のリダイレクト ✅（O-06）

`lib/rdc/templates/redirect.html.erb`:

```erb
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Moved</title>
  <link rel="canonical" href="<%= h.(target) %>">
  <meta http-equiv="refresh" content="0; url=<%= h.(target) %>">
  <script>location.replace(<%= target.to_json %> + location.hash);</script>
</head>
<body><p>This page has moved to <a href="<%= h.(target) %>"><%= h.(target) %></a>.</p></body>
</html>
```

**確認** ✅: `/php.html#r-attributed_top_statement` を開くと `/php/#r-attributed_top_statement` に移動し、ハッシュが維持される。

### T1-8 デプロイワークフロー（O-02）

1. `.github/workflows/deploy.yml` を追加する（アクションは最新のメジャーバージョンを確認して使う）。

   ```yaml
   name: Deploy
   on:
     push:
       branches: [main]
     workflow_dispatch:
   permissions:
     contents: read
     pages: write
     id-token: write
   concurrency:
     group: pages
     cancel-in-progress: false
   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: ruby/setup-ruby@v1
           with: { ruby-version: "3.4", bundler-cache: true }
         - uses: actions/cache@v4
           with:
             path: .cache/src
             key: src-${{ hashFiles('grammars/manifest.yml') }}
         - run: bundle exec exe/rdc build --out dist
         - uses: actions/upload-pages-artifact@v3
           with: { path: dist }
     deploy:
       needs: build
       runs-on: ubuntu-latest
       environment:
         name: github-pages
         url: ${{ steps.deployment.outputs.page_url }}
       steps:
         - id: deployment
           uses: actions/deploy-pages@v4
   ```

2. リポジトリの Settings → Pages → Source を「GitHub Actions」に変更する。
3. 旧構成の HTML ファイルを `main` から削除する。旧 URL はリダイレクトページとして生成される。

### T1-9 出典パネルと注記（B-14, B-15）

各言語ページの冒頭に次を表示する。

- 出典: 文法ファイル名、タグ、コミット（リポジトリへのリンク付き）
- 生成に使った Lrama のバージョン、生成日
- 注記 `parser_grammar`（全言語）と `parse_y_vs_prism`（Ruby のみ）。本文は DESIGN.md の 5.2 節

### T1-10 テスト

`test/slug_test.rb`:

```ruby
require "minitest/autorun"
require_relative "../lib/rdc/slug"

class SlugTest < Minitest::Test
  def test_plain     = assert_equal "r-stmt", Rdc::Slug.rule("stmt")
  def test_midrule   = assert_equal "r-~24~401", Rdc::Slug.rule("$@1")
  def test_quote     = assert_equal "r-option_~27~5Cn~27", Rdc::Slug.rule("option_'\\n'")
  def test_multibyte = assert_equal "r-~E3~81~82", Rdc::Slug.rule("あ")
end
```

- ビルドのスモークテストとして `verify_links!` が通ることを確認する。
- 規則数が Lrama 出力の見出し数と一致することを確認する。

**Phase 1 の完了条件**: `bundle exec exe/rdc build` が成功し、3 言語が最新タグ（PHP 189 / Ruby 305 / Perl 139 規則）で生成される。リンク切れは 0 件で、`main` への push で自動デプロイされる。

---

## 3. Phase 2 — 閲覧体験・アクセシビリティ（2〜3 週）

### T2-1 非終端記号のリンク化 ✅（U-03, B-08）

T1-6 の `link_nonterminals!` で実装済み。旧来のクリック用スクリプトは削除する。

**完了条件**（Chromium で確認済み）:

- Tab キーで図の中の非終端記号にフォーカスでき、Enter で遷移する。
- 中クリックで新しいタブが開く。
- JS を無効にしても遷移できる。

### T2-2 関連ハイライト ✅（B-09）

DESIGN.md の 9.2 節の `highlight.js` を `site/assets/js/` に置き、`app.js` から読み込む。

```js
import { initHighlight } from "./highlight.js";
initHighlight();
```

CSS:

```css
a.rr-nt:hover rect, a.rr-nt.is-related rect { fill: var(--rr-highlight); }
a.rr-nt:focus-visible rect { stroke: var(--focus); stroke-width: 4px; }
.rule-title.is-related { background: var(--rr-highlight); }
```

**完了条件**: ホバーまたはフォーカスで、同じ規則への参照と見出しがハイライトされ、離れると解除される。リスナーは `main` の 4 つだけ。

### T2-3 目次の絞り込み（U-01）

`site/assets/js/toc.js`:

```js
const normalize = (s) => s.toLowerCase().replace(/[_\-\s]/g, "");

function isSubsequence(q, s) {
  let i = 0;
  for (const c of s) if (c === q[i]) i++;
  return i === q.length;
}

export function initTocFilter(input, list) {
  const items = [...list.querySelectorAll("li[data-name]")].map((li) => ({
    li,
    key: normalize(li.dataset.name + " " + (li.dataset.alias ?? "")),
  }));
  input.addEventListener("input", () => {
    const q = normalize(input.value);
    for (const { li, key } of items) li.hidden = q !== "" && !isSubsequence(q, key);
  });
}
```

- 現在表示中の規則は IntersectionObserver で目次側に `aria-current="true"` を付けて示す。
- 768px 未満では目次をドロワーにする。

### T2-4 幅モードとズーム（U-04, B-04）

```css
.diagram-scroll { overflow-x: auto; }
.diagram-scroll > svg { display: block; }
:root[data-width="fit"] .diagram-scroll > svg { width: 100%; height: auto; }
section.rule { content-visibility: auto; }
```

- 図ごとのズームボタンは、SVG の `style.width` に「元の幅 × 倍率」を設定し、`height: auto` にする。
- 設定は `localStorage` の `rdc:width` に保存し、読み書きは `try/catch` で囲む。

### T2-5 ダークモード（U-05）

1. 色を DESIGN.md の 8.5 節の CSS 変数に置き換える。Lrama のインライン配色も上書きする。
2. `<head>` 内で描画前にテーマを適用し、ちらつきを防ぐ。

   ```html
   <script>try{const t=localStorage.getItem("rdc:theme");if(t)document.documentElement.dataset.theme=t}catch(e){}</script>
   ```

### T2-6 Used by と到達パス ✅（U-06, U-08）

T1-6 で実装済み。開始記号は、manifest に `start` がなければ `$accept` が参照する最初の非終端記号とする。

### T2-7 内部規則の表示切替（U-09, B-16）

1. `data-kind="accept|midrule"` の規則は既定で非表示にする（本文・目次とも）。

   ```css
   :root:not([data-internal="show"]) [data-kind="accept"],
   :root:not([data-internal="show"]) [data-kind="midrule"] { display: none; }
   ```

2. 非表示の規則へのリンクを踏んだら自動で表示状態にする（`hashchange` で判定）。
3. パラメータ化規則のインスタンス（`option_…` など）は表示したまま、バッジだけ付ける（図から消すのは Phase 3 の簡約で行う）。

### T2-8 キーボードショートカット（U-10）

| キー | 動作 |
|---|---|
| `/` | 検索（目次の絞り込み）にフォーカス |
| `j` / `k` | 次／前の規則へ |
| `?` | ヘルプ（`<dialog>`） |

入力欄にフォーカスがあるときは無効にする。1 文字ショートカットは設定で無効化できるようにする。

### T2-9 トップページ刷新（U-15）

- 言語カードを manifest とビルド結果から生成する（規則数・終端記号数・バージョン・更新日・出典）。
- 横断検索用の索引 JSON を出力する。
- 「構文図の読み方」を実際の小さな図で示す。

### T2-10 CI 品質ゲート（O-03）

1. `package.json` の devDependencies に次を追加する: `html-validate`、`@playwright/test`、`@axe-core/playwright`、`@lhci/cli`。
2. `.github/workflows/ci.yml` を追加する（雛形）。

   ```yaml
   name: CI
   on:
     pull_request:
     push:
       branches: [main]
   jobs:
     build:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: ruby/setup-ruby@v1
           with: { ruby-version: "3.4", bundler-cache: true }
         - uses: actions/cache@v4
           with: { path: .cache/src, key: "src-${{ hashFiles('grammars/manifest.yml') }}" }
         - run: bundle exec ruby -Itest -e 'Dir["test/**/*_test.rb"].each { require_relative _1 }'
         - run: bundle exec exe/rdc build --out dist
         - uses: actions/upload-artifact@v4
           with: { name: dist, path: dist }
     checks:
       needs: build
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4
         - uses: actions/download-artifact@v4
           with: { name: dist, path: dist }
         - uses: actions/setup-node@v4
           with: { node-version: 22, cache: npm }
         - run: npm ci
         - run: npx html-validate "dist/**/*.html"
         - run: npx playwright install --with-deps chromium
         - run: npx playwright test
         - run: npx lhci autorun
     links:
       needs: build
       runs-on: ubuntu-latest
       steps:
         - uses: actions/download-artifact@v4
           with: { name: dist, path: dist }
         - uses: lycheeverse/lychee-action@v2
           with: { args: "--offline --no-progress 'dist/**/*.html'" }
   ```

3. E2E テスト `e2e/navigation.spec.js` を追加する（同等のシナリオを Python 版 Playwright で確認済み）。

   ```js
   import { test, expect } from "@playwright/test";
   import AxeBuilder from "@axe-core/playwright";

   test("非終端記号から定義へ移動し、戻るで復帰する", async ({ page }) => {
     await page.goto("/php/8.5/");
     const link = page.locator("a.rr-nt").nth(10);
     const target = await link.getAttribute("href");
     await link.click();
     await expect(page).toHaveURL(new RegExp(`${target}$`));
     await page.goBack();
     await expect(page).not.toHaveURL(new RegExp(`${target}$`));
   });

   test("モバイル幅でページ全体が横スクロールしない", async ({ page }) => {
     await page.setViewportSize({ width: 375, height: 800 });
     await page.goto("/php/8.5/");
     expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBe(375);
   });

   test("axe 違反がない", async ({ page }) => {
     await page.goto("/ruby/");
     const results = await new AxeBuilder({ page }).analyze();
     expect(results.violations).toEqual([]);
   });
   ```

4. `playwright.config.js` の `webServer` で `python3 -m http.server 4173 --directory dist` を起動し、`baseURL` をそこに向ける。
5. `lighthouserc.json` で予算を設定する: Performance ≥ 0.9、Accessibility = 1、Best Practices = 1、SEO = 1。

---

## 4. Phase 3 — 文法データの高度化（3〜5 週）

| タスク | 対応 ID | 手順 | 完了条件 |
|---|---|---|---|
| T3-1 スパイクと ADR | G-01 | 2 日で時間を区切り、次の 3 方式を比較する: ① Lrama をライブラリとして使う、② 上流に JSON ダンプを追加（L-04）、③ Bison `.output` の解析。取り出す項目は、規則・選択肢・`%token` の別名・パラメータ化規則の由来・中間アクションの判定。結果を `docs/adr/0001-ir-source.md` に記録する | ADR がマージされている |
| T3-2 IR とスキーマ | G-01 | DESIGN.md 5.3 節の IR を `rdc ir` で `data/` に出力する。`schema/ir-v1.json` で検証し、IR をコミット対象にする | 3 言語の IR がスキーマ検証に通る |
| T3-3 レンダラ | B-17 | railroad-diagrams の Ruby 実装を `lib/rdc/render/railroad/` に vendoring する。非終端記号の href、`data-*`、選択肢ごとの class、`textLength` を付与できるよう拡張し、長さ 0 のパスは出力しない。小さな `.y` でゴールデンテストを作る | 既存ページと同等の見た目で、内部リンク切れが 0 件 |
| T3-4 簡約 | G-03, B-16 | DESIGN.md 6.5 節のパスを 1 つずつ実装し、各パスに単体テストと等価性テスト（ハーネスは検証済み）を付ける。言語別の設定を `meta.yml` の `simplify` に置く。原文どおりの `/raw/` ページも生成する | 全規則で等価性テストが通る。`$@N` が図から消える |
| T3-5 表層トークン | G-02 | 別名の引用符を外して表示する（Ruby の `` `class' `` → `class`、PHP の `'abstract'` → `abstract`）。`meta.yml` の `token_display` で上書きできるようにし、内部名は SVG の `<title>` に入れる | キーワードが実際の綴りで表示される |
| T3-6 BNF 表示 | G-04, B-08 | 規則ごとに `<details>` で BNF を表示し、コピーボタンを付ける | テキスト代替として axe に通る |
| T3-7 終端記号索引 | G-05 | `/<lang>/<ver>/terminals/` を生成し、終端記号ごとにそれを使う規則へのリンクを並べる | 全終端記号が掲載されている |
| T3-8 JSON API | G-08 | `/api/v1/index.json`、`/api/v1/<lang>/<ver>.json`、検索索引を出力する。公開後に `curl -I` で CORS ヘッダーを確認する | スキーマどおりの JSON が取得できる |
| T3-9 プレビューとツールバー | U-07, U-11 | 参照先の図をポップオーバーで表示する（ホバーまたはフォーカスから 300ms 後）。SVG 保存は計算済みスタイルをインライン化してから `XMLSerializer` でシリアライズし、PNG は canvas に 2 倍の解像度で描画する | キーボードでも操作できる |
| T3-10 上流への PR | L-02〜L-05 | 起票済みの Issue に対して修正 PR を出す | マージ、またはメンテナの合意 |

---

## 5. Phase 4 — バージョンと差分（2〜3 週）

### T4-1 複数バージョン（V-01）

1. manifest に旧バージョンを追加する（例: PHP 8.4、Perl 5.42）。
2. バージョン切替 UI ではハッシュを維持する。

   ```js
   select.addEventListener("change", () => {
     location.href = `../${select.value}/${location.hash}`;
   });
   ```

### T4-2 差分エンジン（V-02）

実装は DESIGN.md の 11 節に従う。正規化では次の 2 点が必須。

- 中間アクション記号 `$@N` / `@N` を除去する（実例として、PHP で `@12` が `@11` に変わっている）。
- 記号名は HTML エスケープを解除した生の名前で比較する（Lrama の版によって `>` の出力表記が異なる）。

**受け入れテスト**（現行サイトと最新タグの比較で得た期待値）:

| 言語 | 期待値 |
|---|---|
| PHP | 規則 +5 / −1、終端記号 `T_PIPE` の追加 |
| Ruby | 規則 +10 / −9（名前変更の候補を含む） |
| Perl | 規則 +31 / −5、終端記号 `ATTRLIST`・`PROTOTYPE` の追加 |

### T4-3 差分ページと変更履歴（V-02〜V-04）

1. `/<lang>/diff/<from>...<to>/` と `/<lang>/changelog/` を生成する。
2. 規則と選択肢に「このバージョンで追加」バッジを付ける。

### T4-4 上流監視 ✅（O-04）

`lib/rdc/updates.rb`（検証時は PHP 8.5 と Perl 5.44 を「新版」として検出できた）:

```ruby
# frozen_string_literal: true
require "open3"

module Rdc
  # 上流の新しい安定版タグを検出する（O-04）
  module Updates
    module_function

    # => [[lang, "8.6", "php-8.6.0"], ...]
    def detect(manifest)
      manifest.languages.filter_map do |lang|
        next unless lang.tag_pattern

        pattern = Regexp.new(lang.tag_pattern)
        out, status = Open3.capture2("git", "ls-remote", "--tags", "--refs", lang.repo)
        raise "ls-remote failed: #{lang.repo}" unless status.success?

        known = lang.versions.map(&:ref)
        latest = out.lines.filter_map do |line|
          tag = line.split("\t").last.strip.delete_prefix("refs/tags/")
          m = pattern.match(tag) or next
          [m.captures.map(&:to_i), tag]
        end.max_by(&:first)
        next unless latest && !known.include?(latest.last)

        [lang, latest.first.join("."), latest.last]
      end
    end
  end
end
```

`tag_pattern` のキャプチャを連結したものがバージョン ID になる。

| 言語 | `tag_pattern` |
|---|---|
| PHP | `^php-(\d+)\.(\d+)\.0$` |
| Ruby | `^v(\d+)\.(\d+)\.0$` |
| Perl | `^v(5)\.(\d*[02468])\.0$`（偶数マイナーが安定版） |

`.github/workflows/upstream-watch.yml`（雛形）:

```yaml
name: Upstream watch
on:
  schedule:
    - cron: "0 0 * * 1"   # 毎週月曜 09:00 JST
  workflow_dispatch:
permissions:
  contents: write
  pull-requests: write
jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with: { ruby-version: "3.4", bundler-cache: true }
      - id: check
        run: bundle exec exe/rdc check-updates --write-manifest --summary tmp/summary.md  # updated=true を $GITHUB_OUTPUT に書く
      - if: steps.check.outputs.updated == 'true'
        run: bundle exec exe/rdc fetch && bundle exec exe/rdc ir
      - if: steps.check.outputs.updated == 'true'
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ vars.BOT_APP_ID }}
          private-key: ${{ secrets.BOT_PRIVATE_KEY }}
      - if: steps.check.outputs.updated == 'true'
        uses: peter-evans/create-pull-request@v7
        with:
          token: ${{ steps.app-token.outputs.token }}   # GITHUB_TOKEN で作った PR では CI が起動しないため
          branch: bot/upstream-update
          title: "Update grammars from upstream"
          body-path: tmp/summary.md
          labels: upstream
```

---

## 6. Phase 5 — コンテンツ拡充（継続）

### T5-1 Bison 系言語の追加チェックリスト（C-01）

1. ライセンスを確認し、収録してよいか、帰属表示の文言をどうするかを Issue に記録する。
2. `bundle exec exe/rdc new-lang <id>` で雛形を作る。
3. manifest に `repo`・`grammar`・`ref`・`sparse`・`preprocess`・`tag_pattern` を書く。
4. `rdc fetch <id>` → `rdc build --only <id>` を実行する。Lrama が失敗したら 8 章の表で対処する。
5. `meta.yml` を書く（表示名、`epsilon_rules`、`token_display`、注記）。
6. レビューする。
   - 無作為に選んだ 10 規則を元の文法と目視で照合する。
   - 規則数と終端記号数を元の文法（規則の数、`%token` の数）と照合する。
7. PR を作る。テンプレートのチェックリストをすべて埋める。

候補: PostgreSQL（`src/backend/parser/gram.y`）、Bash（`parse.y`）、gawk（`awkgram.y`）、jq（`src/parser.y`）、mruby（`mrbgems/mruby-compiler/core/parse.y`）。

### T5-2 Yacc 以外のフロントエンド（C-02）

1. `Frontend#load(path, meta) -> IR` を実装する。EBNF・PEG・ANTLR は `?`・`*`・`+` を直接持つので、式木（DESIGN.md 5.4 節）を直接返してよい。
2. 対応方針は形式ごとに次のとおり。
   - ANTLR4: `.g4` のパーサ規則を扱う小さなパーサを書く。アクションとラベルは除去する。
   - W3C 形式 EBNF: 仕様書に記載された文法を読む。
   - PEG（`python.gram`）: 先読み `&` / `!` は注記として描く。
3. フィクスチャとゴールデンテストを必須にする。

### T5-3 コード例（G-10）

1. `grammars/<lang>/examples.yml` に「規則名 → コード片」を書く。
2. CI で公式 Docker イメージ（タグは要確認）を使い、構文チェックを行う: `ruby --parser=parse.y -c`、`php -l`、`perl -c`。
3. `perl -c` は `BEGIN` ブロックを実行するため、秘密情報を持たないジョブで実行する。

### T5-4 その他

- 最短導出例（G-06）を実装する。アルゴリズムは DESIGN.md の 6.4 節（検証済み）。
- カテゴリ（G-09）を付与する。
- UI の多言語化（U-14）と SEO（O-07）を行う。

---

## 7. 運用手順

| 場面 | 手順 |
|---|---|
| 上流更新 PR のレビュー | ① PR 本文の差分要約を読む → ② 変更された規則をプレビューで 3〜5 件確認する → ③ CI が成功していればマージする（自動デプロイ） |
| リリース | `CHANGELOG.md` を更新 → `git tag vX.Y.Z` → GitHub Release を作成 |
| デプロイ失敗 | Actions を再実行する。コードが原因なら該当コミットを revert する（Pages には前回の成果物が残る） |
| Lrama の更新 | `Gemfile.lock` を更新する PR で全言語を再生成し、IR の差分がテンプレート由来の変化だけであることを確認する |

---

## 8. トラブルシューティング

| 症状 | 原因 | 対処 |
|---|---|---|
| `railroad_diagrams is not installed` | gem が入っていない | `Gemfile` に `railroad_diagrams` を追加する |
| `parse error on value '<規則名>' (IDENTIFIER)` | 規則名とコロンの間にコメントがある（Lrama の制約、L-05） | `strip_rule_comments.rb` のような前処理を manifest の `preprocess` に指定する |
| Ruby の parse.y で Lrama がエラーになる | `id2token.rb` の前処理をしていない | `preprocess: "ruby tool/id2token.rb parse.y"`。`sparse` に `/tool/id2token.rb` と `/defs/id.def` を含める |
| `invalid multibyte char (US-ASCII)` | `LANG` が未設定 | `File.read` / `File.write` に `encoding: "UTF-8"` を付ける |
| `git clone --branch` でタグが見つからない | タグ形式の違い（Ruby 4.0 以降は `v4.0.0`） | `git ls-remote --tags --refs <repo>` で実在するタグを確認する |
| 図の文字が箱からはみ出す | フォント幅の差（B-17） | Phase 3 のレンダラで `textLength` を付与する |
| 差分に意味のない変更が大量に出る | 中間アクション番号のずれ、エスケープ表記の差 | DESIGN.md 11 節の正規化を適用する |

---

## 付録: タスクと ID の対応

| Phase | タスク | 対応 ID |
|---|---|---|
| 0 | T0-1〜T0-7 | B-01〜B-05, B-07, B-10〜B-13, C-04, O-05, O-09, L-01, L-02, L-05（起票） |
| 1 | T1-1〜T1-10 | O-01, O-02, O-06, B-06, B-14, B-15, U-02, U-12 |
| 2 | T2-1〜T2-10 | U-01, U-03〜U-06, U-08〜U-10, U-15, B-08, B-09, B-16, O-03 |
| 3 | T3-1〜T3-10 | G-01〜G-05, G-08, U-07, U-11, B-16, B-17, L-02〜L-05 |
| 4 | T4-1〜T4-4 | V-01〜V-04, O-04 |
| 5 | T5-1〜T5-4 | C-01, C-02, G-06, G-09, G-10, U-14, O-07 |
