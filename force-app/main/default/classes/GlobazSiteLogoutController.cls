public without sharing class GlobazSiteLogoutController {

      public PageReference logout() {
          // Remove cookie
          CookieUtils.deleteCookie('globaz_uid');

          ApexPages.addMessage(new ApexPages.Message(
              ApexPages.Severity.INFO,
              'Sessão terminada com sucesso.'
          ));

          PageReference home = new PageReference('/globaztickets');
          home.setRedirect(true);
          return home;
      }
  }
