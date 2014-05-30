class Table < ActiveRecord::Base
	belongs_to :game
	has_one :shoe
	has_many :cards
	has_many :seats
	has_many :users, through: :seats
	before_create :setup
	
	def setup
		self.number = Table.count + 1
		self.shoe = Shoe.create
		self.low = 5
		self.high = 10
		5.times do |i|
			self.seats << Seat.create( number: i + 1  )
		end
		fill_shoe(4)
	end

	def fill_shoe(decks=1)
		decks.times do
			deck = Deck.create
			deck.cards.each { |card| 	self.shoe.cards << card }
		end
	end

  def stand(user)
  	self.increment!(:action, 1)
  	if self.dealers_turn?
  		self.draw
  	end
  end

	def hit(user)
		user.seat.cards << random_card
		if bust(self.count(handify(user.seat.cards)))
			user.seat.update(placed_bet: 0)
			stand(user)		
		end
	end

  def double_down(user)
  	user.decrement!(:chips, user.seat.placed_bet)
  	user.seat.increment!(:placed_bet, user.seat.placed_bet)
  	self.hit(user)
  	self.stand(user)
  end


  def split(user)
  	user.seat.increment!(:placed_bet, user.seat.placed_bet)
  	user.decrement!(:chips, user.seat.placed_bet)
  	user.split_hands = Split.new(user)
  	user.seat.cards = []
  end

  def split_hit(user)
  	user.split_hands.hands.first << random_card
  end

  def split_stand(user)
  	if user.split_hands.hands.count > 1
  		user.seat.cards << user.split_hands.hands.shift
  	elsif user.split_hands.hands.count == 1
  		user.seat.cards << user.split_hands.hands.shift
  		stand(user)
  	else
  		stand(user)
  	end
  end

	def deal
		
		self.next_hand
		self.users.each do |user|
			if user.seat.in_hand?
				2.times { user.seat.cards << random_card }
			end
		end
		2.times { self.cards << random_card }
		if blackjack(self.cards)
			self.end_of_hand = true
			house_blackjack_payouts
		end
	end

	def draw
		hand = self.count(handify(self.cards))
		if self.bust(hand)
			self.update(end_of_hand: true)
			self.dealer_bust_payout
		else
			if hand <= 16 
				self.cards << random_card
				draw
			end
		end
		self.update(end_of_hand: true)
		self.standard_payout(hand)
	end

	def random_card
		cards = []
		self.shoe.cards.each { |card| cards << card if !card.played }
		cards.shuffle.shift.played!
	end

	def next_hand
		self.users.each { |u| u.seat.update(cards: []) }
		self.cards = []
		self.action = 1
		self.end_of_hand = false
		if self.shoe.cards.where(played: false).count < 30
			fill_shoe
		end
	end

	def handify(cards)
		cards.map { |card| card.rank.between?(10,13) ? 10 : card.rank }.sort
	end

	def count(array)
		if array.include?(1)
			if array.inject(:+) + 10 < 21
				array.inject(:+) + 10
			else
				array.inject(:+)
			end
		else
			array.inject(:+)
		end
	end

	def blackjack(cards)
		jack = handify(cards) & [1,10,11,12,13]
		jack.count == 2 && jack.include?(1)
	end

	def bust(number)
		number > 21
	end

  def dealers_turn?
  	active_players = 0
  	self.users.each {|user| active_players += 1 if user.seat.in_hand? }
  	active_players < self.action
  end

	def first_to_act
		self.users.map{ |user| user.seat.number if user.seat.in_hand? }.first
	end

	def player_count
		self.users.count
	end

	def game_name
		self.game.name
	end

	def vacancies
		vacants = []
		self.seats.each do |seat| 
			if !seat.occupied? 
				vacants << seat
			end
		end
		vacants
	end

	def first_vacant
		self.vacancies.sort.first
	end

	def seat_qty
		return 5 if self.game.name == "blackjack" 		
	end

	def full_table?
		self.vacancies.length == 0
	end

### Payouts ###

	def dealer_bust_payout
		self.users.each { |user| win(user) }
	end
			
	def standard_payout(dealer_total)
		self.users.each do |user|
			if user.seat.cards.count > 0
				if user.split_hands
					i = user.seat.cards.index(user.split_hands.split_card)
					first_hand = user.seat.cards[1..i]
					second_hand = user.seat.cards[i+1..-1]
					if count(handify(first_hand)) < dealer_total
						loss(user)
					elsif count(handify(first_hand)) == dealer_total
						push(user)
					else
						win(user)
					end
					if count(handify(second_hand)) < dealer_total
						loss(user)
					elsif count(handify(second_hand)) == dealer_total
						push(user)
					else
						win(user)
					end
				else
					if count(handify(user.seat.cards)) < dealer_total
						loss(user)
					elsif count(handify(user.seat.cards)) == dealer_total
						push(user)
					else
						win(user)
					end
				end
			else 
				loss(user)
			end
		end
	end

	def house_blackjack_payouts
		self.users.each do |user|
			if blackjack(user.seat.cards)
				push(user)
			else
				loss(user)
			end
		end
	end

	def push(user)
		self.game.house.decrement!(:bank, user.seat.placed_bet)
		user.increment!(:chips, user.seat.placed_bet)
		user.seat.update(placed_bet: 0)
	end

	def win(user)
		self.game.house.decrement!(:bank, user.seat.placed_bet)
		user.increment!(:chips, (user.seat.placed_bet * 2))
		user.seat.update(placed_bet: 0)
	end

	def loss(user)
		self.game.house.increment!(:bank, user.seat.placed_bet)
		user.seat.update(placed_bet: 0)
	end

	def winner(user_cards, house_cards)
		result = count(handify(user_cards)) - count(handify(house_cards))
		if result == 0
			"Push"
		elsif result > 0
			"Win"
		elsif result < 0
			"Loss"
		end
	end

end
