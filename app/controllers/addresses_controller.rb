class AddressesController < ApplicationController
  before_action :set_address, only: [ :edit, :update, :destroy, :set_default ]

  def index
    @addresses = Current.user.addresses.order(is_default: :desc, created_at: :asc)
  end

  def new
    @address = Current.user.addresses.build(country: "Indonesia")
  end

  def create
    @address = Current.user.addresses.build(address_params)
    @address.is_default = true if Current.user.addresses.empty?

    if @address.save
      redirect_to addresses_path, notice: "Address saved."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @address.update(address_params)
      redirect_to addresses_path, notice: "Address updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @address.destroy
    redirect_to addresses_path, notice: "Address removed."
  end

  def set_default
    @address.update!(is_default: true)
    redirect_to addresses_path, notice: "Default address updated."
  end

  private

  def set_address
    @address = Current.user.addresses.find(params[:id])
  end

  def address_params
    params.require(:address).permit(:first_name, :last_name, :address1, :city, :state, :zipcode, :country, :phone, :is_default)
  end
end
