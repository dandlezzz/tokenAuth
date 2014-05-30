module Api
	class TablesController < ApplicationController
		respond_to :json
		before_filter :identify_user

		def show
			@table = Table.find(params[:id])
			render json: identify_user.end_state
		end

		def update
			@table = Table.find(params[:id])
			if params[:sit] == 'any'
				identify_user.sit(@table)
			elsif params[:bet]
				identify_user.seat.place_bet(params[:bet].to_i)
			elsif params[:decision]
				if params[:decision] == "hit"
					@table.hit(identify_user)
				elsif params[:decision] == "stand"
					@table.stand(identify_user)
				elsif params[:decision] == "double"
					@table.double_down(identify_user)
				elsif params[:decision] == "split"
					@table.split(identify_user)
				end
			end
			render json: identify_user.state
		end

private
		def identify_user
			ApiKey.find_by(access_token: params[:token]).user
		end
	end
end
