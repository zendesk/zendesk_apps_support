# frozen_string_literal: true

module ZendeskAppsSupport
  module Validations
    module Secrets
      SECRET_KEYWORDS = %w[
        pass password secret secretToken secret_token auth_key
        authKey auth_pass authPass auth_user AuthUser username api_key
      ].freeze

      APPLICATION_SECRETS = {
        # rubocop:disable Metrics/LineLength
        'Slack Token' => /(xox[p|b|o|a]-*.[a-z0-9])/,
        'RSA Private Key' => /-----BEGIN RSA PRIVATE KEY-----/,
        'SSH Private Key (OpenSSH)' => /-----BEGIN OPENSSH PRIVATE KEY-----/,
        'SSH Private Key (DSA)' => /-----BEGIN DSA PRIVATE KEY-----/,
        'SSH Private Key (EC)' => /-----BEGIN EC PRIVATE KEY-----/,
        'PGP Private Key Block' => /-----BEGIN PGP PRIVATE KEY BLOCK-----/,
        'Facebook OAuth Token' => /([f|F][a|A][c|C][e|E][b|B][o|O][o|O][k|K]( [|:\"=-]|[:\"=-|]).*.[0-9a-f]{24,36})/,
        'Twitter OAuth Token' => /([t|T][w|W][i|I][t|T][t|T][e|E][r|R]( [:\"=-]|[:\"=-]).*.[0-9a-zA-Z]{30,45})/,
        'Github Token' => /([g|G][i|I][t|T][h|H][u|U][b|B]( [:\"=-]|[:\"=-]).*.[0-9a-zA-Z]{30,45})/,
        'Google OAuth Token' => /([c|C][l|L][i|I][e|E][n|N][t|T][\-_][s|S][e|E][c|C][r|R][e|E][t|T]( [:\"=-]|[:\"=-]).*[a-zA-Z0-9\-_]{16,32})/,
        'AWS Access Key ID' => /(AKIA[0-9A-Z]{8,24})/,
        'AWS Secret Access Key' => /([a|A][w|W][s|S][_-][s|S][e|E][c|C][r|R][e|E][t|T][_-][a|A][c|C][c|C][e|E][s|S][s|S][_-][k|K][e|E][y|Y].*.[0-9a-zA-Z]{24,48})/,
        'Heroku API Key' => /([h|H][e|E][r|R][o|O][k|K][u|U].*[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{6,18})/,
        'Quickpay Secret' => /(quickpay_secret:.*.[0-9a-zA-Z]{24,72})/,
        'Doorman Secret' => /([d|D][o|O][o|O][r|R][m|M][a|A][n|N][-_][s|S][e|E][c|C][r|R][e|E][t|T].*.[0-9a-f]{16,132})/,
        'Shared Session Secret' => /(shared_session_secret.*.[0-9a-f]{4,132})/,
        'Permanent Cookie Secret' => /(permanent_cookie_secret.*.[0-9a-f]{120,156})/,
        'Scarlett AWS Secret Key' => /([sS][cC][aA][rR][lL][eE][tT][tT][_-][aA][wW][sS][_-][sS][eE][cC][rR][eE][tT][_-][kK][eE][yY].*.[0-9a-zA-Z+.]{35,45})/,
        'Braintree Key' => /(braintree_key.*.[0-9a-zA-Z]{16,36})/,
        'Ticket Validation Key' => /(ticket_validation_key.*.[0-9a-zA-Z]{15,25})/,
        'App Key' => /([aA][pP][pP][-_][kK][eE][yY]( [:\"=-]|[:\"=-]).*.[0-9a-zA-Z+_.-]{4,156})/,
        'App Secret' => /([aA][pP][pP][-_][sS][eE][cC][rR][eE][tT]( [:\"=-]|[:\"=-]).*.[0-9a-zA-Z+_.-]{4,156})/,
        'Consumer Key' => /([cC][oO][nN][sS][uU][mM][eE][rR][-_][kK][eE][yY]( [:\"=-]|[:\"=-]).*.[0-9a-zA-Z+_.-]{4,156})/,
        'Consumer Secret' => /([cC][oO][nN][sS][uU][mM][eE][rR][-_][sS][eE][cC][rR][eE][tT]( [:\"=-]|[:\"=-]).*.[0-9a-zA-Z+_.-]{4,156})/,
        'Generic Secret' => /(?m)^([sS][eE][cC][rR][eE][tT]( [:\"=-]|[:\"=-]).*.[0-9a-zA-Z+_.-]{4,156})/,
        'Master Key' => /([mM][aA][sS][tT][eE][rR][-_][kK][eE][yY]( [:\"=-]|[:\"=-]).*.[0-9a-zA-Z+_.-]{4,156})/,
        'Master Secret' => /([mM][aA][sS][tT][eE][rR][-_][sS][eE][cC][rR][eE][tT]( [:\"=-]|[:\"=-]).*.[0-9a-zA-Z+_.-]{4,156})/,
        'Token Key' => /([tT][oO][kK][eE][nN][-_][kK][eE][yY]( [:\"=-]|[:\"=-]).*.[0-9a-zA-Z+_.-]{4,156})/,
        'Token Secret' => /([tT][oO][kK][eE][nN][-_][sS][eE][cC][rR][eE][tT]( [:\"=-]|[:\"=-]).*.[0-9a-zA-Z+_.-]{4,156})/,
        'Zendesk Zopim Mobile SSO Key' => /(zendesk_zopim_mobile_sso_key.*.[0-9a-f]{58,68})/,
        'Help Center Private Key' => /([pP][rR][iI][vV][aA][tT][eE][-_][kK][eE][yY]( [:\"=-]|[:\"=-]).*.[0-9a-zA-Z+_.-]{4,156})/,
        'X-Outbound-Key' => /([xX][-][oO][uU][tT][bB][oO][uU][nN][dD][-][kK][eE][yY][:\" \t=-].*.[0-9a-z-]{32,36})/,
        'Attachment Token Key' => /(attachment_token_key.*.[0-9a-f]{24,72})/,
        'Password' => /([pP][aA][sS][sS][wW][oO][rR][dD].*.[0-9a-zA-Z+_.-]{4,156})/,
        'Token' => /([tT][oO][kK][eE][nN]( [:\"=-]|[:\"=-]).*.[0-9a-zA-Z+_.-]{4,156})/
        # rubocop:enable Metrics/LineLength
      }.freeze

      class << self
        def call(package)
          compromised_files = package.text_files.map do |file|
            contents = file.read

            APPLICATION_SECRETS.each do |secret_type, regex_str|
              next unless contents =~ Regexp.new(regex_str)
              package.warnings << I18n.t('txt.apps.admin.warning.app_build.application_secret',
                                         file: file.relative_path,
                                         secret_type: secret_type)
            end

            file.relative_path if contents =~ Regexp.union(SECRET_KEYWORDS)
          end.compact

          if compromised_files.any?
            package.warnings << I18n.t('txt.apps.admin.warning.app_build.generic_secrets',
                                       files: compromised_files.join(', '),
                                       count: compromised_files.count)
          end
          []
        end
      end
    end
  end
end
