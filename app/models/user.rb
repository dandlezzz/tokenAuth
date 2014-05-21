class User < ActiveRecord::Base
  attr_accessor :login
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable
  validates :email, presence: true, length: { minimum: 3, maximum: 50 }
  validates :email, uniqueness: true
  validates :username, :uniqueness => { :case_sensitive => false }
  has_one :api_key
  has_one :seat
  has_one :table, through: :seat
  has_many :cards, through: :seat

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
    state = {}
    !self.seat.table.number.nil?  ? state["table #"] = self.seat.table.number : state["table #"] = ''
    !self.seat.table.game.name.nil?  ? state["Game name"] = self.seat.table.game.name : state["Game name"] = ''
    !self.seat.cards.nil?  ? state["Hand"] = self.seat.cards : state["Hand"] = ''
    # !self.seat.placed_bet > 0  ? state["Bet"] = self.seat.placed_bet : state["Bet"] = 0
    !self.seat.table.cards.nil?  ? state["House cards"] = self.seat.table.cards : state["House cards"] = ''
    state
  end

  def end_state
    table = self.seat.table
    state = {}
    state["table #"] = table.number if !table.number.nil? 
    state["Game name"] = table.game.name if !table.game.name.nil?
    state["Hand"] = self.seat.cards if !self.seat.cards.nil?
    state["Bet"] = self.seat.placed_bet if !self.seat.placed_bet == 0
    state["House cards"] = table.cards if !table.cards.nil?
    state["User Hand Value"] = table.handify(self.seat.cards) if !self.seat.cards.nil?
    state["House Hand Value"] = table.handify(table.cards) if !table.cards.nil?
    state["Result"] = table.winner(self.seat.cards, table.cards)
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
