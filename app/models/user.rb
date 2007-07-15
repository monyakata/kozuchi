class User < ActiveRecord::Base
  include LoginEngine::AuthenticatedUser

  has_one   :preferences,
            :class_name => "Preferences",
            :dependent => true
  has_many  :friends,
            :dependent => true
  has_many  :friend_applicants,
            :class_name => 'Friend',
            :foreign_key => 'friend_user_id',
            :dependent => true
  has_many  :accounts,
            :class_name => 'Account::Base',
            :dependent => true,
            :include => [:associated_accounts, :any_entry], # 削除に関係がある
            :order => 'accounts.sort_key' do
              # 指定した account_type のものだけを抽出する
              def types_in(*account_types)
                account_types = account_types.flatten
                self.select{|a| account_types.detect{|t| a.type_in?(t)} }
              end
            end

  def default_asset
    accounts.types_in(:asset).first
  end

  # all logic has been moved into login_engine/lib/login_engine/authenticated_user.rb
  def login_id
    self.login
  end
  
  # 双方向に指定level以上のフレンドを返す
  def interactive_friends(level)
    # TODO 効率悪い
    friend_users = []
    for l in friends(true)
      friend_users << l.friend_user if l.friend_level >= level && l.friend_user.friends(true).detect{|e|e.friend_user_id == self.id && e.friend_level >= level}
    end
    return friend_users
  end

  def self.find_friend_of(user_id, login_id)
    if 2 == Friend.count(:joins => "as fr inner join users as us on ((fr.user_id = us.id and fr.friend_user_id = #{user_id}) or (fr.user_id = #{user_id} and fr.friend_user_id = us.id))",
                   :conditions => ["us.login = ? and fr.friend_level > 0", login_id])
      return find_by_login_id(login_id)
    end
  end

  def self.is_friend(user1_id, user2_id)
    return 2 == Friend.count(:conditions => ["(user_id = ? and friend_user_id = ? and friend_level > 0) or (user_id = ? and friend_user_id == ? and friend_level > 0)", user1_id, user2_id, user2_id, user1_id])
  end


  def self.find_by_login_id(login_id)
    find(:first, :conditions => ["login = ? ", login_id])
  end
  
  # 指定された期間の取引データを取得する。
  # TODO: 口座によらない自由な期間のメソッドがほしくなったら Account に別のスタティックを作りここのデフォルトをnilにしてよびかえる
  def deals(start_date, end_date, accounts)
    BaseDeal.get_for_accounts(self.id, start_date, end_date, accounts)
  end
  
  def deal_exists?(date)
    BaseDeal.exists?(self.id, date)
  end
  
  # このユーザーが使える asset_type (Class) リストを返す
  def available_asset_types
    Account::Asset.types.find_all{|type| !type.business_only? || preferences.business_use? }
  end
  
  protected
  
  def after_create
    create_preferences()
    Account::Base.create_default_accounts(self.id)
  end
  
end
