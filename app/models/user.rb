class User < ActiveRecord::Base
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  validates :email, presence: true, length: { minimum: 3, maximum: 50 }
  validates :email, uniqueness: true
  validates :username, :uniqueness => { :case_sensitive => false }
  has_one :api_key
  has_one :seat
  has_one :table, through: :seat
  has_many :cards, through: :seat
  before_create :setup

  def setup
    self.chips = 500
  end

  def sit(table, seatnumber=nil)
    if seatnumber == nil
      table.first_vacant.update(user_id: self.id)
    elsif table.seats[seatnumber].occupied?
      false
    else
      table.vacancies[seatnumber].update(user_id: self.id)
    end
  end

  def seated?
    !self.seat.nil?
  end

  def leave_table
    self.update(seat: nil)
  end

  def first_open(game)
    matching_tables =[]
    Table.all.each do |t|
      if t.game_name == game
        matching_tables << t
      end
    end
    matching_tables.reject{ |t| t.full_table?  }
    self.sit(matching_tables.first)
  end

  def state
    table = self.seat.table
    state = {}
    state["Table #"] ||= table.number
    state["Game name"] ||= table.game.name
    !self.seat.cards.nil?  ? state["Hand"] = self.seat.cards : state["Hand"] = ''
    !state["Bet"] = self.seat.placed_bet
    !table.cards.nil?  ? state["House cards"] = table.cards : state["House cards"] = ''
    !table.action.nil? ? state["Action on"] = table.action : state["Action on"] = 0
    state["Table limit"] = [table.low, table.high] if !table.low.nil? && !table.high.nil?
    state["User Current Chips"] = self.chips
    state["User Hand Value"] = table.handify(self.seat.cards) if !self.seat.cards.nil?
    state["House Hand Value"] = table.handify(table.cards) if !table.cards.nil?
    
    state
  end

  def set_gravatar_url
    hash = Digest::MD5.hexdigest(self.email.downcase.strip)
    update_attributes(gravatar_url: "http://gravatar.com/avatar/#{hash}") 
  end

  def sign_in
    ApiKey.create(user_id: self.id)
  end

  def sign_out
    ApiKey.find_by(user_id: self.id).destroy
  end

  def signed_in?
   !ApiKey.find_by(user_id: self.id).nil? 
  end
end
