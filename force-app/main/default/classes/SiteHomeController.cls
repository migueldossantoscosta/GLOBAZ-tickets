public without sharing class SiteHomeController {

      public List<Evento__c> featuredEvents { get; set; }
      public List<Evento__c> nextEvents { get; set; }

      public SiteHomeController() {
          loadFeaturedEvents();
          loadNextEvents();
      }

      private void loadFeaturedEvents() {
          featuredEvents = [
              SELECT Id, Name, DataEvento__c, LocalizacaoEvento__c,
                     URLImagem__c, CategoriaPrincipal__c, Destaque__c,
                     Recinto__c, Recinto__r.Cidade__c
              FROM Evento__c
              WHERE DataEvento__c != null AND DataEvento__c >= :System.now()
                AND Destaque__c = true
              ORDER BY DataEvento__c ASC LIMIT 6
          ];
      }

      private void loadNextEvents() {
          nextEvents = [
              SELECT Id, Name, DataEvento__c, LocalizacaoEvento__c,
                     URLImagem__c, CategoriaPrincipal__c, Destaque__c,
                     Recinto__c, Recinto__r.Cidade__c
              FROM Evento__c
              WHERE DataEvento__c != null AND DataEvento__c >= :System.now()
              ORDER BY Destaque__c DESC, DataEvento__c ASC LIMIT 24
          ];
      }

      public Boolean getHasFeaturedEvents() {
          return featuredEvents != null && !featuredEvents.isEmpty();
      }

      public Boolean getHasNextEvents() {
          return nextEvents != null && !nextEvents.isEmpty();
      }
  }