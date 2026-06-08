class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :documents, dependent: :destroy
  has_many :folders, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :messages, through: :conversations
  has_many :tags, dependent: :destroy

  # validates :first_name, presence: true
  # validates :last_name, presence: true
  # validates :email, uniqueness: { scope: :password }

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         # for Google OmniAuth
         :omniauthable, omniauth_providers:[:google_oauth2]

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_initialize do |user|
      user.email      = auth.info.email
      user.first_name = auth.info.first_name
      user.last_name  = auth.info.last_name
      user.password   = Devise.friendly_token[0, 20]
    end
  end
end
