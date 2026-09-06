namespace :tokko do
  desc "Bootstrap the first production owner from TOKKO_OWNER_EMAIL/TOKKO_OWNER_PASSWORD"
  task bootstrap_owner: :environment do
    email = ENV["TOKKO_OWNER_EMAIL"]
    password = ENV["TOKKO_OWNER_PASSWORD"]

    abort("TOKKO_OWNER_EMAIL is required and must not be blank.") if email.blank?
    abort("TOKKO_OWNER_PASSWORD is required and must not be blank.") if password.blank?
    abort("TOKKO_OWNER_PASSWORD must be at least 12 characters.") if password.length < 12

    normalized_email = User.normalize_value_for(:email_address, email)
    owner_email = nil

    User.transaction do
      # Serializes concurrent bootstrap attempts so two operators can't both
      # observe "no owner yet" and each create a first owner. Scoped to this
      # transaction only — releases automatically on commit or rollback.
      User.connection.execute("LOCK TABLE #{User.quoted_table_name} IN SHARE ROW EXCLUSIVE MODE")

      other_owner = User.owner.where.not(email_address: normalized_email).first
      if other_owner
        abort("An owner already exists (#{other_owner.email_address}). Refusing to create another owner via bootstrap.")
      end

      user = User.find_or_initialize_by(email_address: normalized_email)
      user.role = :owner
      user.password = password
      user.save!
      owner_email = user.email_address
    end

    puts "Owner ready: #{owner_email}"
  end
end
