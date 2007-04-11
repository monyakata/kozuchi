class ExpertConfigController < ApplicationController
  layout 'main'
  
  PAYMENT_TERM_MONTHS = [['当月', 0], ['翌月', 1], ['翌々月', 2]]  
  
  def index
    redirect_to(:action => "account_rules")
  end  
  
  # 精算ルールのメンテナンス -----------------------------------------------------------------------
  def account_rules
    @rules = AccountRule.find_all(session[:user].id)
    @accounts_to_be_applied = Account.find_rule_free(session[:user].id)
    @accounts_to_be_associated = Account.find_all(session[:user].id, [1], [Account::ASSET_BANKING_FACILITY])
    @creatable = false
    @rule = AccountRule.new
    @day_options = ExpertConfigController.day_options
    @payment_term_months = PAYMENT_TERM_MONTHS
    if @accounts_to_be_applied.size == 0
      @explanation = "新たに精算ルールを登録できる口座（クレジットカード、債権）はありません。"
      return;
    end
    if @accounts_to_be_associated.size == 0
      @explanation = "精算ルールを登録するには、金融機関口座が必要です。"
      return;
    end
    @creatable = true
  end
  
  def self.day_options
    day_options = []
    for var in 1..28
      day_options << ["#{var}日", var]
    end
    day_options << ['末日', 0]
    day_options
  end
  
  def create_account_rule
    rule = AccountRule.new(params[:rule])
    rule.user_id = session[:user].id
    p rule.account_id
    begin
      rule.save!
      flash[:notice] = "#{rule.account.name}に精算ルールを登録しました。"
    rescue ActiveRecord::RecordInvalid => error
      flash[:notice] = "#{rule.account.name}に精算ルールを登録できませんでした。#{error}"
    end
    redirect_to(:action => 'account_rules')
  end
  
  def delete_account_rule
    target = AccountRule.get(session[:user].id, params[:id].to_i)
    if target
      target_account_name = target.account.name
      target.destroy
      flash[:notice] = "#{target_account_name}から精算ルールを削除しました。"
    else
      flash[:notice] = "精算ルールを削除できません。"
    end
    redirect_to(:action => 'account_rules')
  end
  
  def update_account_rule
    p params.to_s
    p params[:rule].to_s
    rule = AccountRule.get(user.id, params[:rule][:id].to_i)
    if rule
      rule.attributes = params[:rule]
      begin
        rule.save!
        flash[:notice] = "精算ルールを変更しました。"
      rescue
        flash_validation_errors(rule)
      end
    else
      flash_error("指定された精算ルール( #{params[:rule][:id]} )が見つかりません。 ")
    end
  
    redirect_to(:action => 'account_rules')
  end
  
  # フレンド設定
  def friends
    # フレンド関係をもっている、あるいは向こうからこちらにフレンド関係をもっている user のリストを得る
    @friends = Friend.get_all(user.id)
    for f in @friends
      p f.my_level
    end
    
  end
  
  def create_friend
    friend_login_id = @params[:friend_login_id]
    if !friend_login_id || friend_login_id == ""
      flash_error("ユーザーIDを入力してください。")
      redirect_to(:action => 'friends')
      return
    end

    friend_user = get_friend_user(friend_login_id)
    return if !friend_user
    
    save_friend(Friend.new(:user_id => user.id, :friend_user_id => friend_user.id, :friend_level => 1), "ユーザー'#{friend_login_id}'にフレンド申請をしました。")
  end
  
  def accept_friend
    friend_user = User.find_by_login_id(params[:friend])
    return if !friend_user
    
    save_friend(Friend.new(:user_id => user.id, :friend_user_id => friend_user.id, :friend_level => 1), "#{friend_user.login_id}さんからのフレンド申請を承諾しました。")
  end
  
  def clear_friend
    friend_user = User.find_by_login_id(params[:friend])
    return if !friend_user
    
    friend = Friend.find(:first, :conditions => ["user_id = ? and friend_user_id = ?", user.id, friend_user.id])
    before_level = friend.friend_level
    friend.destroy if friend
    if before_level == -1
      flash_notice("#{friend_user.login_id}さんへのフレンド拒否状態を解除しました。フレンド登録するには新たに申請を行ってください。")
    else
      flash_notice("#{friend_user.login_id}さんへのフレンド申請を取り消しました。フレンド登録するには新たに申請を行ってください。")
    end
    
    redirect_to(:action => 'friends')
  end
  
  def reject_friend
    friend_user = User.find_by_login_id(params[:friend])
    return if !friend_user
    friend = Friend.find(:first, :conditions => ["user_id = ? and friend_user_id = ?", user.id, friend_user.id])
    friend ||= Friend.new(:user_id => user.id, :friend_user_id => friend_user.id)
    
    friend.friend_level = -1
    
    save_friend(friend, "#{friend_user.login_id}さんとフレンドになることを拒否しました。")
  end
  
  def get_friend_user(friend_login_id)
    friend_user = User.find_by_login_id(friend_login_id)
    if !friend_user
      flash_error("ユーザー'#{friend_login_id}'を見つけられませんでした。IDが合っているか確認してください。")
      redirect_to(:action => 'friends')
      return nil
    end
    return friend_user
  end
  
  def save_friend(friend, notice)
    begin
      friend.save!
      flash_notice(notice)
    rescue
      flash_validation_errors(friend)
    end
    
    redirect_to(:action => 'friends')
  end

  # カスタマイズ （個人的好みによる設定） ----------------------------------------------------------------
  def preferences
    @preferences = Preferences.get(user.id)
  end
  
  def update_preferences
    preferences = Preferences.get(user.id)
    preferences.attributes = params[:preferences]
    begin
      preferences.save!
      session[:user] = User.find(user.id)
      flash_notice("更新しました。")
    rescue
      flash_validation_errors(preferences)
    end
    redirect_to(:action => 'preferences')
  end

  
end
