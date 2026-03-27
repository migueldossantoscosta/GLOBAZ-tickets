public without sharing class GlobazSiteRegisterController {

      public class RegisterException extends Exception {}

      public String firstName { get; set; }
      public String lastName { get; set; }
      public String email { get; set; }
      public String phone { get; set; }
      public String birthdateText { get; set; }
      public String password { get; set; }
      public String confirmPassword { get; set; }
      public Boolean marketingOptIn { get; set; }
      public Boolean rgpdAccepted { get; set; }

      private static final String GLOBAL_SALT = 'GLOBAZ_TICKETS_2026_SECRET_KEY_XPTO';

      public PageReference registerUser() {
          Savepoint sp = Database.setSavepoint();

          try {
              validateInput();

              Id personAccountRtId = getPersonAccountRecordTypeId();
              Id adminOwnerId = getDefaultOwnerId();

              // Criar hash da password
              String passwordHash = generatePasswordHash(password);

              Account pa = new Account();
              pa.RecordTypeId = personAccountRtId;
              pa.OwnerId = adminOwnerId;
              pa.FirstName = firstName;
              pa.LastName = lastName;
              pa.PersonEmail = email;
              pa.Phone = phone;
              pa.Marketing__c = marketingOptIn;
              pa.Password__c = passwordHash;  // Campo chama-se Password__c

              if (rgpdAccepted) {
                  pa.RGPD__c = System.now();
              }

              if (!String.isBlank(birthdateText)) {
                  pa.DataNascimento__c = parseDatePT(birthdateText);
              }

              insert pa;

              ApexPages.addMessage(new ApexPages.Message(
                  ApexPages.Severity.INFO,
                  'Conta criada com sucesso! Podes fazer login.'
              ));

              // Set user account ID in cookie after registration
              CookieUtils.setCookie('globaz_uid', pa.Id, 7);

              PageReference loginPage = new PageReference('/apex/SiteLogin');
              loginPage.setRedirect(true);
              return loginPage;

          } catch (Exception e) {
              Database.rollback(sp);
              ApexPages.addMessage(new ApexPages.Message(
                  ApexPages.Severity.ERROR,
                  'Erro: ' + e.getMessage()
              ));
              return null;
          }
      }

      private String generatePasswordHash(String pwd) {
          String toHash = pwd + GLOBAL_SALT;
          Blob hashBlob = Crypto.generateDigest('SHA256', Blob.valueOf(toHash));
          return EncodingUtil.convertToHex(hashBlob);
      }

      public static Boolean verifyPassword(String pwd, String storedHash) {
          String inputHash = generatePasswordHashStatic(pwd);
          return inputHash == storedHash;
      }

      private static String generatePasswordHashStatic(String pwd) {
          String toHash = pwd + GLOBAL_SALT;
          Blob hashBlob = Crypto.generateDigest('SHA256', Blob.valueOf(toHash));
          return EncodingUtil.convertToHex(hashBlob);
      }

      private void validateInput() {
          if (String.isBlank(firstName)) throw new RegisterException('Indica o primeiro nome.');
          if (String.isBlank(lastName)) throw new RegisterException('Indica o último nome.');
          if (String.isBlank(email)) throw new RegisterException('Indica o email.');
          if (String.isBlank(password) || String.isBlank(confirmPassword))
              throw new RegisterException('Indica e confirma a password.');
          if (password != confirmPassword)
              throw new RegisterException('As passwords não coincidem.');
          if (!rgpdAccepted)
              throw new RegisterException('Tens de aceitar a política de privacidade.');

          Integer existingAccounts = [SELECT COUNT() FROM Account WHERE IsPersonAccount = true AND PersonEmail = :email];
          if (existingAccounts > 0)
              throw new RegisterException('Já existe uma conta com este email.');
      }

      private static Id getPersonAccountRecordTypeId() {
          List<RecordType> personRT = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND IsPersonType = true LIMIT 1];
          if (personRT.isEmpty()) throw new RegisterException('Person Accounts não estão ativas.');
          return personRT[0].Id;
      }

      private static Id getDefaultOwnerId() {
          List<User> users = [SELECT Id FROM User WHERE IsActive = true AND UserRoleId != null ORDER BY CreatedDate ASC LIMIT 1];
          if (users.isEmpty()) {
              users = [SELECT Id FROM User WHERE IsActive = true AND Profile.Name LIKE '%Admin%' ORDER BY CreatedDate ASC LIMIT 1];
          }
          return users.isEmpty() ? UserInfo.getUserId() : users[0].Id;
      }

      private Date parseDatePT(String inputDate) {
          try {
              String cleanDate = inputDate != null ? inputDate.trim() : '';
              if (String.isBlank(cleanDate)) return null;

              if (cleanDate.contains('/')) {
                  List<String> parts = cleanDate.split('/');
                  if (parts.size() != 3) throw new RegisterException('Data inválida. Usa DD/MM/AAAA.');
                  return Date.newInstance(
                      Integer.valueOf(parts[2]),
                      Integer.valueOf(parts[1]),
                      Integer.valueOf(parts[0])
                  );
              }
              if (cleanDate.contains('-')) return Date.valueOf(cleanDate);
              throw new RegisterException('Data inválida. Usa DD/MM/AAAA ou AAAA-MM-DD.');
          } catch (Exception e) {
              throw new RegisterException('Data de nascimento inválida.');
          }
      }
  }
