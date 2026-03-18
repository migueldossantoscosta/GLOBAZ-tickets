public class BilheteiraController {
    
    public Id idDoEvento {get;set;}
    public Id idDaAccount {get;set;}

    public BilheteiraController(ApexPages.StandardController controller) {
        this.idDoEvento = 'a03d200001dzD7rAAE'; 
        this.idDaAccount = '001d200001UmD61AAF'; 
    }

    @RemoteAction
    public static List<String> getLugaresOcupados(Id eventoId) {
        List<String> ocupados = new List<String>();
        for(Bilhete__c b : [SELECT Fila__c, NumeroLugar__c FROM Bilhete__c WHERE Evento__c = :eventoId]) {
            ocupados.add(b.Fila__c + '-' + b.NumeroLugar__c);
        }
        return ocupados;
    }

    @RemoteAction
    public static String criarReserva(Id eventoId, Id accountId, String metodo, String jsonBilhetes) {
        try {
            Order ord = new Order(
                AccountId = accountId, Evento__c = eventoId, EffectiveDate = Date.today(), 
                Status = 'Draft', MetodoPagamento__c = metodo, QuantidadeBilhetes__c = 0 
            );
            insert ord;

            // FIX: Recebemos como List<Object> para evitar o erro de conversão runtime
            List<Object> rawInputs = (List<Object>) JSON.deserializeUntyped(jsonBilhetes);
            List<Bilhete__c> bilhetesParaCriar = new List<Bilhete__c>();
            
            for(Object obj : rawInputs) {
                Map<String, Object> m = (Map<String, Object>)obj;
                bilhetesParaCriar.add(new Bilhete__c(
                    Order__c = ord.Id,
                    Evento__c = eventoId,
                    Fila__c = (String)m.get('fila'),
                    NumeroLugar__c = (Integer)m.get('lugar'),
                    EstadoBilhete__c = 'Pendente'
                ));
            }

            if(!bilhetesParaCriar.isEmpty()) {
                insert bilhetesParaCriar;
                ord.QuantidadeBilhetes__c = bilhetesParaCriar.size();
                update ord;
            }
            return ord.Id;
        } catch (Exception e) { return 'ERRO: ' + e.getMessage(); }
    }

    @RemoteAction
    public static String processarPagamentoMock(Id orderId) {
        try {
            List<Bilhete__c> bilhetes = [SELECT Id FROM Bilhete__c WHERE Order__c = :orderId];
            for(Bilhete__c b : bilhetes) { 
                b.EstadoBilhete__c = 'Vendido'; 
            }
            // O UPDATE DISPARA O TRIGGER QUE RECALCULA AS COMISSÕES
            update bilhetes;
            
            return 'PAGAMENTO_OK';
        } catch (Exception e) { return 'Erro: ' + e.getMessage(); }
    }
}