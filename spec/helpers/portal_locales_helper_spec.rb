require 'rails_helper'

describe PortalLocalesHelper do
  describe '#portal_locale_flag' do
    it 'maps a locale to its representative flag' do
      expect(helper.portal_locale_flag('ja')).to eq('jp')
      expect(helper.portal_locale_flag('ko')).to eq('kr')
      expect(helper.portal_locale_flag('en')).to eq('us')
    end

    it 'distinguishes regional variants of the same language' do
      expect(helper.portal_locale_flag('zh_TW')).to eq('tw')
      expect(helper.portal_locale_flag('zh_CN')).to eq('cn')
      expect(helper.portal_locale_flag('pt_BR')).to eq('br')
    end

    it 'falls back to the base language when the variant is unmapped' do
      expect(helper.portal_locale_flag('fr_CA')).to eq('fr')
    end

    it 'returns nil rather than a wrong flag when the language has none' do
      expect(helper.portal_locale_flag('eo')).to be_nil
      expect(helper.portal_locale_flag('')).to be_nil
    end

    it 'only names flags that are actually vendored' do
      described_class::LOCALE_FLAGS.each_value do |flag|
        expect(Rails.public_path.join('flags', "#{flag}.svg")).to exist
      end
    end
  end

  describe '#portal_locale_label' do
    it "uses the language's own name so it stays readable in any UI locale" do
      expect(helper.portal_locale_label('ja')).to eq('日本語')
      expect(helper.portal_locale_label('ko')).to eq('한국어')
      expect(helper.portal_locale_label('ar')).to eq('العربية')
    end

    it 'strips the language code that LANGUAGES_CONFIG appends' do
      expect(helper.portal_locale_label('en')).to eq('English')
      expect(helper.portal_locale_label('pt_BR')).to eq('Português Brasileiro')
    end

    it 'writes Chinese variants in their own script' do
      expect(helper.portal_locale_label('zh_TW')).to eq('繁體中文')
      expect(helper.portal_locale_label('zh_CN')).to eq('简体中文')
    end

    it 'falls back to the language map for a locale outside LANGUAGES_CONFIG' do
      expect(helper.portal_locale_label('af')).to eq('Afrikaans')
    end
  end
end
