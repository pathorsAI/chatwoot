# Presentation for the help center's language switcher: the flag to show and the
# name to show it next to.
module PortalLocalesHelper
  # Locale => the flag file in public/flags (vendored from HatScripts/circle-flags,
  # MIT — see public/flags/LICENSE). A language is not a country, so these are the
  # conventional stand-ins, not claims: `ar` flies Saudi Arabia, `ta` Sri Lanka,
  # `en` the US because that is what the rest of the product already shows.
  # Anything missing here falls back to the globe icon rather than a wrong flag.
  LOCALE_FLAGS = {
    'ar' => 'sa', 'bg' => 'bg', 'bn' => 'bd', 'cs' => 'cz', 'da' => 'dk',
    'de' => 'de', 'el' => 'gr', 'en' => 'us', 'es' => 'es', 'et' => 'ee',
    'fa' => 'ir', 'fi' => 'fi', 'fr' => 'fr', 'he' => 'il', 'hi' => 'in',
    'hr' => 'hr', 'hu' => 'hu', 'id' => 'id', 'is' => 'is', 'it' => 'it',
    'ja' => 'jp', 'ko' => 'kr', 'lt' => 'lt', 'lv' => 'lv', 'ms' => 'my',
    'nl' => 'nl', 'no' => 'no', 'pl' => 'pl', 'pt' => 'pt', 'pt_BR' => 'br',
    'ro' => 'ro', 'ru' => 'ru', 'sk' => 'sk', 'sl' => 'si', 'sr' => 'rs',
    'sv' => 'se', 'ta' => 'lk', 'th' => 'th', 'tl' => 'ph', 'tr' => 'tr',
    'uk' => 'ua', 'ur' => 'pk', 'ur_IN' => 'in', 'vi' => 'vn', 'zh' => 'cn',
    'zh_CN' => 'cn', 'zh_TW' => 'tw'
  }.freeze

  # LANGUAGES_CONFIG names read `日本語 (ja)` — the code is redundant beside a flag.
  LANGUAGE_CODE_SUFFIX = /\s*\([a-z]{2}(?:-[A-Za-z]{2,4})?\)\s*\z/i

  # Upstream labels zh-TW in Simplified characters. A visitor picking Traditional
  # Chinese should see it written the way they write it.
  LOCALE_LABEL_OVERRIDES = { 'zh_TW' => '繁體中文', 'zh_CN' => '简体中文' }.freeze

  def portal_locale_flag(locale)
    code = locale.to_s
    LOCALE_FLAGS[code] || LOCALE_FLAGS[code.split('_').first]
  end

  # The language's own name, so it stays readable whatever the page is rendered in
  # — someone who only reads Korean has to find 한국어, not "Korean".
  def portal_locale_label(locale)
    code = locale.to_s
    return LOCALE_LABEL_OVERRIDES[code] if LOCALE_LABEL_OVERRIDES.key?(code)

    entry = LANGUAGES_CONFIG.values.find { |lang| lang[:iso_639_1_code] == code }
    return language_name(code) if entry.blank?

    entry[:name].sub(LANGUAGE_CODE_SUFFIX, '').strip
  end
end
