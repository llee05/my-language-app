#include "FHashTable.hpp"
#include "json.hpp"
#include <libsecret/secret.h>
#include <cstring>
#include <memory>
#include <stdexcept>
#include <string>

#define secret_autofree _GLIB_CLEANUP(secret_cleanup_free)
static inline void secret_cleanup_free(gchar **p) { secret_password_free(*p); }

class LibsecretError : public std::runtime_error {
  std::string error_code;

  static const char *codeFromGError(const GError *error) {
    if (error == nullptr) {
      return "Libsecret error";
    }

    if (g_error_matches(error, SECRET_ERROR, SECRET_ERROR_IS_LOCKED)) {
      return "KeyringLocked";
    }

    if (g_error_matches(error, SECRET_ERROR, SECRET_ERROR_NO_SUCH_OBJECT)) {
      return "SecretNotFound";
    }

    return "Libsecret error";
  }

  static std::string messageWithContext(const char *context,
                                        const char *message) {
    if (message == nullptr) {
      return context == nullptr ? "Libsecret error" : context;
    }

    if (context == nullptr || context[0] == '\0') {
      return message;
    }

    std::string result(context);
    result += ": ";
    result += message;
    return result;
  }

public:
  explicit LibsecretError(const char *message)
      : LibsecretError("Libsecret error", message) {}

  LibsecretError(const char *code, const char *message)
      : std::runtime_error(
            message == nullptr
                ? (code == nullptr ? "Libsecret error" : code)
                : message),
        error_code(code == nullptr ? "Libsecret error" : code) {}

  LibsecretError(const char *context, const GError *error)
      : std::runtime_error(messageWithContext(
            context, error == nullptr ? nullptr : error->message)),
        error_code(codeFromGError(error)) {}

  const char *code() const { return error_code.c_str(); }
};

class SecretStorage {
  FHashTable m_attributes;
  std::string label;
  SecretSchema the_schema;

public:
  const char *getLabel() { return label.c_str(); }
  void setLabel(const char *label) {
    this->label = label;
    // Rebuild the schema so its name points at the live label string. The
    // schema used to be built in the constructor while the label still held
    // its short "default" value; once setLabel moved the string to the heap,
    // the schema name dangled and items were stored and searched under
    // whatever bytes the abandoned buffer contained (upstream issue
    // juliansteenbakker/flutter_secure_storage#1230).
    the_schema = {this->label.c_str(), SECRET_SCHEMA_NONE,
                  {{"account", SECRET_SCHEMA_ATTRIBUTE_STRING}}};
  }

  SecretStorage(const char *_label = "default") : label(_label) {
    the_schema = {label.c_str(),
                  SECRET_SCHEMA_NONE,
                  {
                      {"account", SECRET_SCHEMA_ATTRIBUTE_STRING},
                  }};
  }

  void addAttribute(const char *key, const char *value) {
    m_attributes.insert(key, value);
  }

  bool addItem(const char *key, const char *value) {
    nlohmann::json root = readFromKeyring();
    root[key] = value;
    return storeToKeyring(root);
  }

  std::string getItem(const char *key) {
    std::string result;
    nlohmann::json root = readFromKeyring();
    nlohmann::json value = root[key];
    if(value.is_string()){
      result = value.get<std::string>();
      return result;
    }
    return "";
  }

  void deleteItem(const char *key) {
    nlohmann::json root = readFromKeyring();
    if (!root.is_object() || !root.contains(key)) {
      return;
    }
    root.erase(key);
    storeToKeyring(root);
  }

  bool deleteKeyring() {
    if (!warmupKeyring()) {
      return true;
    }
    return this->storeToKeyring(nlohmann::json::object());
  }

  bool storeToKeyring(nlohmann::json value) {
    const std::string output = value.dump();

    // gnome-keyring 50.x can accept a store and still persist the item
    // without its secret body; replacements of such a hollow item stay
    // broken afterwards. Verify every store by reading it back through the
    // keyring and, when the secret did not land, remove the hollow item and
    // re-create it from scratch.
    for (int attempt = 0; attempt < 3; attempt++) {
      g_autoptr(GError) err = nullptr;
      gboolean result = secret_password_storev_sync(
          &the_schema, m_attributes.getGHashTable(), nullptr, label.c_str(),
          output.c_str(), nullptr, &err);

      if (err) {
        throw LibsecretError("secret_password_storev_sync", err);
      }
      if (!result) {
        return false;
      }

      g_autofree gchar *stored = secret_password_lookupv_sync(
          &the_schema, m_attributes.getGHashTable(), nullptr, &err);
      if (err) {
        throw LibsecretError("secret_password_lookupv_sync", err);
      }
      if (stored != nullptr && strcmp(stored, output.c_str()) == 0) {
        return true;
      }

      g_autoptr(GError) clearErr = nullptr;
      gboolean cleared = secret_password_clearv_sync(
          &the_schema, m_attributes.getGHashTable(), nullptr, &clearErr);
      if (clearErr) {
        throw LibsecretError("secret_password_clearv_sync", clearErr);
      }
      if (!cleared) {
        return false;
      }
    }

    throw LibsecretError("secret store verification",
                         "The keyring did not persist the secret");
  }

  nlohmann::json readFromKeyring() {
    nlohmann::json value = nlohmann::json::object();
    g_autoptr(GError) err = nullptr;

    if (!warmupKeyring()) {
      return value;
    }

    secret_autofree gchar *result = secret_password_lookupv_sync(
        &the_schema, m_attributes.getGHashTable(), nullptr, &err);

    if (err) {
      throw LibsecretError("secret_password_lookupv_sync", err);
    }
    if(result != NULL && strcmp(result, "") != 0){
      value = nlohmann::json::parse(result);
    }
    return value;
  }

private:
  // Ensures the default keyring is accessible and distinguishes a locked
  // collection from other storage errors. A missing default collection is
  // the normal state of a fresh profile, not a locked keyring. Do not load
  // all collections here: some Secret Service backends fail when an
  // unrelated stale item exists in another collection.
  bool warmupKeyring() {
    g_autoptr(GError) err = nullptr;

    SecretService *service = secret_service_get_sync(
        SECRET_SERVICE_OPEN_SESSION, nullptr, &err);

    if (!service) {
      throw LibsecretError("secret_service_get_sync", err);
    }

    SecretCollection *collection = secret_collection_for_alias_sync(
        service, SECRET_COLLECTION_DEFAULT, SECRET_COLLECTION_NONE, nullptr, &err);

    if (!collection) {
      const bool missingDefaultCollection = err == nullptr;
      if (missingDefaultCollection) {
        g_autoptr(GError) searchError = nullptr;
        GList *matchingItems = secret_service_search_sync(
            service, &the_schema, m_attributes.getGHashTable(),
            SECRET_SEARCH_NONE, nullptr, &searchError);
        const bool hasMatchingItems = matchingItems != nullptr;
        if (matchingItems) {
          g_list_free_full(matchingItems, g_object_unref);
        }
        g_object_unref(service);

        // With no alias and no matching item this is a fresh profile. If data
        // exists elsewhere, fail closed before a write can create a second
        // default collection and orphan the original item.
        if (searchError) {
          throw LibsecretError("secret_service_search_sync", searchError);
        }
        if (hasMatchingItems) {
          throw LibsecretError("KeyringLocked", "KeyringLocked");
        }
        return false;
      }
      g_object_unref(service);
      throw LibsecretError("secret_collection_for_alias_sync", err);
    }

    if (!secret_collection_get_locked(collection)) {
      g_object_unref(collection);
      g_object_unref(service);
      return true;
    }

    GList *to_unlock = g_list_append(nullptr, collection);
    GList *unlocked_out = nullptr;
    gint n = secret_service_unlock_sync(service, to_unlock, nullptr, &unlocked_out, nullptr);
    g_list_free(to_unlock);
    if (unlocked_out) {
      g_list_free_full(unlocked_out, g_object_unref);
    }
    g_object_unref(collection);
    g_object_unref(service);

    if (n == 0) {
      throw LibsecretError("KeyringLocked", "KeyringLocked");
    }

    return true;
  }
};
