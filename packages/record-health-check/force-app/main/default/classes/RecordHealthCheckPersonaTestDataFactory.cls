/** Creates test users for locale, permission, and ownership scenarios. */
@IsTest
public class RecordHealthCheckPersonaTestDataFactory {
  /** Returns a lightweight reference to the running user. */
  public static User currentUser() {
    return new User(Id = UserInfo.getUserId());
  }

  /** Creates a uniquely named inactive user. */
  public static User createInactiveUser(String firstName, String lastName) {
    List<Profile> standardProfiles = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    Id profileId = standardProfiles.isEmpty()
      ? [SELECT Id FROM Profile LIMIT 1].Id
      : standardProfiles[0].Id;
    String unique = 'rhc.inactive.' + DateTime.now().getTime();
    return createUser(
      new User(
        FirstName = firstName,
        LastName = lastName,
        Alias = 'rhcinact',
        Email = unique + '@example.invalid',
        Username = unique + '@example.invalid',
        ProfileId = profileId,
        TimeZoneSidKey = 'America/Chicago',
        LocaleSidKey = 'en_US',
        EmailEncodingKey = 'UTF-8',
        LanguageLocaleKey = 'en_US',
        IsActive = false
      )
    );
  }

  /** Creates a user with the Minimum Access profile. */
  public static User createMinimumAccessUser(String alias) {
    Profile profile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Minimum Access - Salesforce'
      LIMIT 1
    ];
    String token = uniqueToken();
    User result = new User(
      Alias = alias,
      Email = 'rhc.' + alias + '@example.invalid',
      EmailEncodingKey = 'UTF-8',
      LastName = 'RHC Minimum',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = profile.Id,
      TimeZoneSidKey = 'America/Chicago',
      Username = 'rhc.' + alias + '.' + token + '@example.invalid'
    );
    System.runAs(currentUser()) {
      insert result;
    }
    return result;
  }

  /** Persists and returns a supplied user. */
  public static User createUser(User userRecord) {
    insert userRecord;
    return userRecord;
  }

  /** Creates a user pinned to a locale for deterministic display assertions. */
  public static User createUserWithLocale(String localeSidKey, String alias) {
    Profile standardProfile = [
      SELECT Id
      FROM Profile
      WHERE Name = 'Standard User'
      LIMIT 1
    ];
    String token = uniqueToken();
    User localeUser = new User(
      ProfileId = standardProfile.Id,
      LastName = 'Display Format',
      Alias = alias,
      Email = 'rhc.' + alias + '@example.invalid',
      Username = 'rhc.' + alias + '.' + token + '@example.invalid',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = localeSidKey,
      TimeZoneSidKey = 'America/Los_Angeles'
    );
    System.runAs(currentUser()) {
      insert localeUser;
    }
    return localeUser;
  }

  private static String uniqueToken() {
    String token = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
    return token.length() > 8 ? token.right(8) : token;
  }
}
