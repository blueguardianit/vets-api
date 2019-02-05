# Subclasses the UserIdentity class in order to override the redis namespace and thereby partition
# user sessions for va.gov from openid client applications.
class OpenidUserIdentity < ::UserIdentity
  redis_store REDIS_CONFIG['openid_user_identity_store']['namespace']
  redis_ttl REDIS_CONFIG['openid_user_identity_store']['each_ttl']
  redis_key :uuid
end

