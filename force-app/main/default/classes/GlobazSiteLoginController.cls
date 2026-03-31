public without sharing class GlobazSiteLoginController {

      public class LoginException extends Exception {}

      public String email { get; set; }
      public String password { get; set; }

      private static final String GLOBAL_SALT = 'GLOBAZ_TICKETS_2026_SECRET_KEY_XPTO';

      public PageReference login() {
          try {
              validateInput();

              List<Account> accounts = [
                  SELECT Id, PersonEmail, Password__c, FirstName
                  FROM Account
                  WHERE IsPersonAccount = true
                  AND PersonEmail = :email
                  LIMIT 1
              ];

              if (accounts.isEmpty()) {
                  ApexPages.addMessage(new ApexPages.Message(
                      ApexPages.Severity.ERROR,
                      'Email ou password inválidos.'
                  ));
                  return null;
              }

              Account acc = accounts[0];

              if (!verifyPassword(password, acc.Password__c)) {
                  ApexPages.addMessage(new ApexPages.Message(
                      ApexPages.Severity.ERROR,
                      'Email ou password inválidos.'
                  ));
                  return null;
              }

              ApexPages.addMessage(new ApexPages.Message(
                  ApexPages.Severity.INFO,
                  'Login bem-sucedido! Bem-vindo, ' + acc.FirstName + '.'
              ));

              // Redirect com UID na URL
              PageReference home = new PageReference('/apex/HomeEventos?uid=' + acc.Id);
              home.setRedirect(true);
              return home;

          } catch (Exception e) {
              ApexPages.addMessage(new ApexPages.Message(
                  ApexPages.Severity.ERROR,
                  'Erro: ' + e.getMessage()
              ));
              return null;
          }
      }

      private void validateInput() {
          if (String.isBlank(email)) {
              throw new LoginException('Indica o email.');
          }
          if (String.isBlank(password)) {
              throw new LoginException('Indica a password.');
          }
      }

      private static String generatePasswordHash(String pwd) {
          String toHash = pwd + GLOBAL_SALT;
          Blob hashBlob = Crypto.generateDigest('SHA256', Blob.valueOf(toHash));
          return EncodingUtil.convertToHex(hashBlob);
      }

      public static Boolean verifyPassword(String pwd, String storedHash) {
          String inputHash = generatePasswordHash(pwd);
          return inputHash == storedHash;
      }
  }