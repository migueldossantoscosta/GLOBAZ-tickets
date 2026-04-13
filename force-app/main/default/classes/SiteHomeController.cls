public without sharing class SiteHomeController {

    public List<EventoWrapper> featuredEvents { get; set; }
    public List<EventoWrapper> nextEvents { get; set; }

    public SiteHomeController() {
        loadFeaturedEvents();
        loadNextEvents();
    }

    private void loadFeaturedEvents() {
        List<Evento__c> events = [
            SELECT Id, Name, DataEvento__c, LocalizacaoEvento__c,
                   URLImagem__c, CategoriaPrincipal__c, Destaque__c,
                   Recinto__c, Recinto__r.Cidade__c
            FROM Evento__c
            WHERE DataEvento__c != null AND DataEvento__c >= :System.now()
              AND Destaque__c = true
            ORDER BY DataEvento__c ASC LIMIT 6
        ];
        featuredEvents = wrapEvents(events);
    }

    private void loadNextEvents() {
        List<Evento__c> events = [
            SELECT Id, Name, DataEvento__c, LocalizacaoEvento__c,
                   URLImagem__c, CategoriaPrincipal__c, Destaque__c,
                   Recinto__c, Recinto__r.Cidade__c
            FROM Evento__c
            WHERE DataEvento__c != null AND DataEvento__c >= :System.now()
            ORDER BY Destaque__c DESC, DataEvento__c ASC LIMIT 24
        ];
        nextEvents = wrapEvents(events);
    }

    private List<EventoWrapper> wrapEvents(List<Evento__c> events) {
        List<EventoWrapper> wrappers = new List<EventoWrapper>();
        for (Evento__c e : events) {
            wrappers.add(new EventoWrapper(e));
        }
        return wrappers;
    }

    public Boolean getHasFeaturedEvents() {
        return featuredEvents != null && !featuredEvents.isEmpty();
    }

    public Boolean getHasNextEvents() {
        return nextEvents != null && !nextEvents.isEmpty();
    }

    public class EventoWrapper {
        public Evento__c ev { get; set; }
        public String formattedDate { get; set; }
        public String city { get; set; }
        public String imageUrl { get; set; }

        public EventoWrapper(Evento__c e) {
            this.ev = e;
            this.city = (e.Recinto__r != null && e.Recinto__r.Cidade__c != null) ? e.Recinto__r.Cidade__c : (e.LocalizacaoEvento__c != null ? e.LocalizacaoEvento__c : 'Local a definir');
            this.imageUrl = e.URLImagem__c; // Use raw field value as it already contains the full URL
            
            if (e.DataEvento__c != null) {
                this.formattedDate = e.DataEvento__c.format('dd MMM yyyy HH:mm');
            } else {
                this.formattedDate = 'Data a anunciar';
            }
        }
    }
}