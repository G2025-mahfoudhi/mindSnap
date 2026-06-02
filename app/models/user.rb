class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :documents, dependent: :destroy
  has_many :folders, dependent: :destroy
  has_many :conversations, dependent: :destroy
  has_many :messages, through: :conversations

  # validates :first_name, presence: true
  # validates :last_name, presence: true
  validates :email, uniqueness: { scope: :password }
end
