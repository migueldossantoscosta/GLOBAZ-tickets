public without sharing class GlobazSiteLogoutController {

      public PageReference logout() {
          ApexPages.addMessage(new ApexPages.Message(
              ApexPages.Severity.INFO,
              'Sessão terminada com sucesso.'
          ));

          PageReference home = new PageReference('/apex/HomeEventos');
          home.setRedirect(true);
          return home;
      }
  }