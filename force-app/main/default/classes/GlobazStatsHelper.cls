public without sharing class GlobazStatsHelper {
    public class Stats {
        public Decimal total {get;set;}
        public String totalStr {get;set;}
        public String lastDate {get;set;}
        public Stats() {
            this.total = 0.0;
            this.totalStr = '0.00';
            this.lastDate = 'Sem compras';
        }
    }

    public static Stats getAccountStats(String accId) {
        Stats s = new Stats();
        if (String.isBlank(accId)) return s;

        try {
            // Busca manual de ordens ativadas
            List<Order> orders = [SELECT TotalAmount, EffectiveDate FROM Order WHERE AccountId = :accId AND Status = 'Activated'];
            Decimal sum = 0;
            Date lastD = null;
            for (Order o : orders) {
                if (o.TotalAmount != null) sum += o.TotalAmount;
                if (o.EffectiveDate != null && (lastD == null || o.EffectiveDate > lastD)) lastD = o.EffectiveDate;
            }
            
            // Fallback via bilhetes se as ordens não forem visíveis/existirem
            if (lastD == null) {
                List<Bilhete__c> tickets = [SELECT CreatedDate FROM Bilhete__c WHERE Account__c = :accId ORDER BY CreatedDate DESC LIMIT 1];
                if (!tickets.isEmpty()) lastD = tickets[0].CreatedDate.date();
            }

            s.total = sum;
            s.totalStr = sum.setScale(2).format();
            s.lastDate = (lastD != null) ? lastD.format() : 'Sem compras';
            
            System.debug('>>> Helper Stats para ' + accId + ': ' + s.totalStr + ' - ' + s.lastDate);
        } catch (Exception ex) {
            System.debug('>>> Erro no Helper Stats: ' + ex.getMessage());
        }
        return s;
    }
}
