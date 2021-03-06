class FastbillAPI
  require 'fastbill-automatic'

  #Here be FastBill stuff
  #
  # The fastbill_chain takes control of all the necessary steps to handle
  # fastbill customer creation and adding transactions fees to a user's
  # fastbill account
  def self.fastbill_chain transaction
    seller = transaction.seller
    seller.with_lock do
      unless seller.ngo?
        unless seller.has_fastbill_profile?
          fastbill_create_customer seller
          fastbill_create_subscription seller
        end

        [ :fair, :fee ].each do | type |
          fastbill_setusagedata seller, transaction, type
        end

        fastbill_discount seller, transaction if transaction.discount
      end
    end
  end

  private
    def self.fastbill_create_customer seller
      unless seller.fastbill_id
        User.observers.disable :user_observer do
          customer = Fastbill::Automatic::Customer.create( customer_number: seller.id,
                                              customer_type: seller.is_a?(LegalEntity) ? 'business' : 'consumer',
                                              organization: (seller.company_name? && seller.is_a?(LegalEntity)) ? seller.company_name : seller.nickname,
                                              salutation: seller.title,
                                              first_name: seller.forename,
                                              last_name: seller.surname,
                                              address: seller.street,
                                              address_2: seller.address_suffix,
                                              zipcode: seller.zip,
                                              city: seller.city,
                                              country_code: 'DE',
                                              language_code: 'DE',
                                              email: seller.email,
                                              currency_code: 'EUR',
                                              payment_type: '1', # Ueberweisung
                                              # payment_type: '2', # Bankeinzug # Bitte aktivieren, wenn Genehmigung der Bank vorliegt
                                              show_payment_notice: '1',
                                              bank_name: seller.bank_name,
                                              bank_code: seller.bank_code,
                                              bank_account_number: seller.bank_account_number,
                                              bank_account_owner: seller.bank_account_owner
                                            )
          seller.fastbill_id = customer.customer_id
          seller.save
        end
      end
    end

    def self.update_profile user
      customer = Fastbill::Automatic::Customer.get( customer_id: user.fastbill_id ).first
      if customer
        customer.update_attributes( customer_id: user.fastbill_id,
                                  customer_type: "#{ user.is_a?(LegalEntity) ? 'business' : 'consumer' }",
                                  organization: (user.company_name? && user.is_a?(LegalEntity)) ? user.company_name : user.nickname,
                                  first_name: user.forename,
                                  last_name: user.surname,
                                  address: user.street,
                                  address_2: user.address_suffix,
                                  zipcode: user.zip,
                                  city: user.city,
                                  country_code: 'DE',
                                  language_code: 'DE',
                                  email: user.email,
                                  currency_code: 'EUR',
                                  payment_type: '1', # Ueberweisung
                                  # payment_type: user.direct_debit ? '2' : '1', # Bitte aktivieren, wenn Genehmigung der Bank vorliegt
                                  show_payment_notice: '1',
                                  bank_name: user.bank_name,
                                  bank_code: user.bank_code,
                                  bank_account_number: user.bank_account_number,
                                  bank_account_owner: user.bank_account_owner
                                )
      end
    end

    def self.fastbill_create_subscription seller
      unless seller.fastbill_subscription_id
        User.observers.disable :user_observer do
          subscription = Fastbill::Automatic::Subscription.create( article_number: '10',
                                                    customer_id: seller.fastbill_id,
                                                    next_event: Time.now.end_of_month.strftime("%Y-%m-%d %H:%M:%S")
                                                  )
          seller.fastbill_subscription_id = subscription.subscription_id
          seller.save
        end
      end
    end

    # This method adds articles and their according fee type to the invoice
    def self.fastbill_setusagedata seller, transaction, fee_type
      unless (fee_type == :fair && transaction.billed_for_fair) || (fee_type == :fee && transaction.billed_for_fee)
        article = transaction.article

        Fastbill::Automatic::Subscription.setusagedata( subscription_id: seller.fastbill_subscription_id,
                                                        article_number: fee_type == :fair ? '11' : '12',
                                                        quantity: transaction.quantity_bought,
                                                        unit_price: fee_type == :fair ? ( fair_wo_vat article ) : ( fee_wo_vat article ),
                                                        description: transaction.id.to_s + "  " + article.title + " (#{ fee_type == :fair ? I18n.t( 'invoice.fair' ) : I18n.t( 'invoice.fee' )})",
                                                        usage_date: transaction.sold_at.strftime("%Y-%m-%d %H:%M:%S")
                                                      )
        transaction.update_attribute("billed_for_#{fee_type}".to_sym, true)
      end
    end

    # This method adds an discount (if discount is given for transaction)
    def self.fastbill_discount seller, transaction
      unless transaction.billed_for_discount
        article = transaction.article

        Fastbill::Automatic::Subscription.setusagedata( subscription_id: seller.fastbill_subscription_id,
                                                        article_number: '12',
                                                        unit_price: -( discount_wo_vat transaction ),
                                                        description: transaction.id.to_s + "  " + article.title + " (" + transaction.discount_title + ")",
                                                        usage_date: transaction.sold_at.strftime("%Y-%m-%d %H:%M:%S")
                                                      )
        transaction.update_attribute(:billed_for_discount, true)
      end
    end

    # This method adds an refund to the invoice is refund is requested for an article
    def self.fastbill_refund transaction, fee_type
      article = transaction.article
      seller = transaction.seller

      Fastbill::Automatic::Subscription.setusagedata( subscription_id: seller.fastbill_subscription_id,
                                                      article_number: fee_type == :fair ? '11' : '12',
                                                      quantity: transaction.quantity_bought,
                                                      unit_price: fee_type == :fair ? -( fair_wo_vat article ) : -( actual_fee_wo_vat transaction ),
                                                      description: transaction.id.to_s + "  " + article.title + " (#{ fee_type == :fair ? I18n.t( 'invoice.refund_fair' ) : I18n.t( 'invoice.refund_fee' ) })",
                                                      usage_date: transaction.sold_at.strftime("%Y-%m-%d %H:%M:%S")
                                                    )
        transaction.update_attribute("billed_for_#{fee_type}".to_sym, false)
    end

    # This methods calculate the fee without vat
    def self.fair_wo_vat article
      (article.calculated_fair_cents.to_f / 100 / 1.19).round(2)
    end

    def self.fee_wo_vat article
      (article.calculated_fee_cents.to_f / 100 / 1.19).round(2)
    end

    def self.discount_wo_vat transaction
      (transaction.discount_value_cents.to_f / 100 / 1.19).round(2)
    end

    def self.actual_fee_wo_vat transaction
      fee = fee_wo_vat( transaction.article )
      fee -= discount_wo_vat( transaction ) if transaction.discount
      fee
    end
end
