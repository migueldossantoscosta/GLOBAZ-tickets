public with sharing class CrmTicketController {
    
    @AuraEnabled(cacheable=true)
    public static List<TicketWrapper> getTicketsByRecordId(Id recordId) {
        List<TicketWrapper> results = new List<TicketWrapper>();
        
        if (recordId == null) {
            return results;
        }

        String sObjectType = recordId.getSObjectType().getDescribe().getName();
        Id accountId = null;

        if (sObjectType == 'Account') {
            accountId = recordId;
        } else if (sObjectType == 'Contact') {
            Contact c = [SELECT AccountId FROM Contact WHERE Id = :recordId LIMIT 1];
            accountId = c.AccountId;
        }

        if (accountId == null) {
            return results;
        }

        List<Bilhete__c> bilhetes = [
            SELECT Id, Name, Fila__c, NumeroLugar__c, EstadoBilhete__c,
                   Evento__r.Name, Evento__r.DataEvento__c,
                   Order__r.Name
            FROM   Bilhete__c
            WHERE  Account__c = :accountId
            ORDER BY Evento__r.DataEvento__c DESC, Name ASC
        ];

        for (Bilhete__c b : bilhetes) {
            results.add(new TicketWrapper(b));
        }

        return results;
    }

    @AuraEnabled
    public static void reenviarPdf(Id ticketId) {
        if (ticketId == null) {
            throw new AuraHandledException('ID do bilhete é nulo.');
        }
        // Chamando a lógica de envio de email existente
        EnviarBilhetePDF.enviarEmailFuturo(new List<Id>{ ticketId });
    }

    @AuraEnabled
    public static void cancelarBilhete(Id ticketId) {
        if (ticketId == null) {
            throw new AuraHandledException('ID do bilhete é nulo.');
        }
        try {
            Bilhete__c b = [SELECT Id, EstadoBilhete__c FROM Bilhete__c WHERE Id = :ticketId LIMIT 1];
            b.EstadoBilhete__c = 'Cancelado';
            update b;
        } catch (Exception e) {
            throw new AuraHandledException('Erro ao cancelar bilhete: ' + e.getMessage());
        }
    }

    public class TicketWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String eventoNome { get; set; }
        @AuraEnabled public String data { get; set; }
        @AuraEnabled public String lugar { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String statusClass { get; set; }
        @AuraEnabled public Boolean isValido { get; set; }
        @AuraEnabled public String codigo { get; set; }

        public TicketWrapper(Bilhete__c b) {
            this.id = b.Id;
            this.name = b.Name;
            this.eventoNome = b.Evento__r.Name;
            this.data = b.Evento__r.DataEvento__c != null ? b.Evento__r.DataEvento__c.format('dd/MM/yyyy HH:mm') : '';
            this.lugar = 'Fila ' + b.Fila__c + ' - Lugar ' + b.NumeroLugar__c;
            this.status = b.EstadoBilhete__c;
            this.codigo = b.Name; // Usando o Name como código para exibição
            this.isValido = (b.EstadoBilhete__c == 'Vendido');
            
            if (this.isValido) {
                this.statusClass = 'badge success';
            } else if (b.EstadoBilhete__c == 'Cancelado') {
                this.statusClass = 'badge danger';
            } else {
                this.statusClass = 'badge neutral';
            }
        }
    }
}
