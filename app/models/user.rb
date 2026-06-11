class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         # for Google OmniAuth
         :omniauthable, omniauth_providers:[:google_oauth2]

  PLANS = {
    "free"     => { label: "Gratuit",  document_limit: 50,  price_monthly: 0,    price_annual: 0 },
    "pro"      => { label: "Pro",      document_limit: 500, price_monthly: 5.90, price_annual: 4.90 },
    "business" => { label: "Business", document_limit: nil, price_monthly: 15,   price_annual: 12.50 }
  }.freeze

  def document_limit
    PLANS.key?(plan) ? PLANS.dig(plan, :document_limit) : 50
  end

  def plan_label
    PLANS.dig(plan, :label) || "Gratuit"
  end

  has_one_attached :avatar

  has_many :documents, dependent: :destroy
  has_many :folders, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :messages, through: :conversations
  has_many :tags, dependent: :destroy

  validates :first_name, presence: true
  validates :last_name, presence: true
  # validates :email, uniqueness: { scope: :password }

  def self.from_omniauth(auth)
    user = where(provider: auth.provider, uid: auth.uid).first_or_initialize do |u|
      u.email      = auth.info.email
      u.first_name = auth.info.first_name
      u.last_name  = auth.info.last_name
      u.password   = Devise.friendly_token[0, 20]
    end
    user.save
    user.attach_google_avatar(auth.info.image) if !user.avatar.attached? && auth.info.image.present?
    user
  end

  def attach_google_avatar(url)
    require "open-uri"
    file = URI.parse(url).open
    avatar.attach(io: file, filename: "avatar.jpg", content_type: "image/jpeg")
  end
end
