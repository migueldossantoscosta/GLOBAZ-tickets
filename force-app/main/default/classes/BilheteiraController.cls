public class BilheteiraController {
    
    public BilheteiraController(ApexPages.StandardController controller) {}

    public class BilheteInput {
        public String fila {get;set;}
        public Integer lugar {get;set;}
    }

    // MÉTODO 1: Cria a Order automaticamente e retorna o ID
    @RemoteAction
    public static String iniciarCompra(Id eventoId, Id accountId) {
    try {
        Order novaOrder = new Order(
            AccountId = accountId,
            Evento__c = eventoId,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            QuantidadeBilhetes__c = 0, // Garante que começa a zero
            MetodoPagamento__c = 'Cartão' // Como aparece no teu print
        );
        insert novaOrder;
        return novaOrder.Id;
    } catch (Exception e) {
        return 'ERRO:' + e.getMessage();
    }
}

    // MÉTODO 2: Cria os bilhetes, valida duplicados e atualiza a quantidade
    @RemoteAction
    public static String finalizarCompra(Id orderId, String jsonBilhetes) {
        try {
            Order ord = [SELECT Id, Evento__c, AccountId FROM Order WHERE Id = :orderId LIMIT 1];
            List<BilheteInput> inputs = (List<BilheteInput>) JSON.deserialize(jsonBilhetes, List<BilheteInput>.class);
            
            if(inputs.isEmpty()) return 'Erro: Seleciona pelo menos um lugar.';

            List<Bilhete__c> bilhetesParaCriar = new List<Bilhete__c>();
            for(BilheteInput b : inputs) {
                bilhetesParaCriar.add(new Bilhete__c(
                    Order__c = ord.Id,
                    Evento__c = ord.Evento__c,
                    Account__c = ord.AccountId,
                    Fila__c = b.fila,
                    NumeroLugar__c = b.lugar,
                    EstadoBilhete__c = 'Vendido'
                ));
            }
            
            insert bilhetesParaCriar;

            // Atualiza a quantidade para o valor da Order bater certo
            ord.QuantidadeBilhetes__c = bilhetesParaCriar.size();
            update ord;
            
            return 'OK';
            
        } catch (DmlException e) {
            if (e.getDmlType(0) == StatusCode.DUPLICATE_VALUE) {
                return '❌ ERRO: Um dos lugares já está ocupado! Escolhe outro.';
            }
            return 'Erro: ' + e.getDmlMessage(0);
        } catch (Exception e) {
            return 'Erro inesperado: ' + e.getMessage();
        }
    }
}