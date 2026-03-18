public class BilheteiraController {
    
    public Id idDoEvento  {get;set;}
    public Id idDaAccount {get;set;}

    public BilheteiraController(ApexPages.StandardController controller) {
       this.idDoEvento  = 'a03d200001fPjvmAAC'; 
       this.idDaAccount = '001d200001UmD61AAF';  
    }

    @RemoteAction
    public static List<String> getLugaresOcupados(Id eventoId) {
        List<String> ocupados = new List<String>();
        for(Bilhete__c b : [
            SELECT Fila__c, NumeroLugar__c 
            FROM Bilhete__c 
            WHERE Evento__c = :eventoId 
            AND EstadoBilhete__c = 'Vendido'
        ]) {
            ocupados.add(b.Fila__c + '-' + b.NumeroLugar__c);
        }
        return ocupados;
    }

    // FIX 2 — método novo para buscar o mapa do evento
    @RemoteAction
    public static String getMapaConfig(Id eventoId) {
        try {
            Evento__c evt = [
                SELECT MapaConfig__c 
                FROM Evento__c 
                WHERE Id = :eventoId 
                LIMIT 1
            ];
            if (String.isBlank(evt.MapaConfig__c)) {
                return 'ERRO: Mapa não configurado para este evento.';
            }
            return evt.MapaConfig__c;
        } catch (Exception e) { return 'ERRO: ' + e.getMessage(); }
    }

    @RemoteAction
    public static String criarReserva(Id eventoId, Id accountId, String metodo) {
        try {
            Account acc = [SELECT Id, Valido__c FROM Account WHERE Id = :accountId LIMIT 1];
            if (!acc.Valido__c) {
                return 'CLIENTE_INVALIDO';
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://bilheteira-loba.free.beeceptor.com/pagamento');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody('{"clienteId":"' + accountId + '","status":"processar"}');
            req.setTimeout(10000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                return 'PAGAMENTO_RECUSADO';
            }

            Order ord = new Order(
                AccountId             = accountId,
                Evento__c             = eventoId,
                EffectiveDate         = Date.today(),
                Status                = 'Draft',
                MetodoPagamento__c    = metodo,
                QuantidadeBilhetes__c = 0
            );
            insert ord;

            return ord.Id;

        } catch (Exception e) { return 'ERRO: ' + e.getMessage(); }
    }

    @RemoteAction
    public static String processarPagamentoMock(Id orderId, Id eventoId, String jsonBilhetes) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://bilheteira-loba.free.beeceptor.com/pagamento');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody('{"orderId":"' + orderId + '","status":"confirmar"}');
            req.setTimeout(10000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                return 'PAGAMENTO_RECUSADO';
            }

            List<Object> rawInputs = (List<Object>) JSON.deserializeUntyped(jsonBilhetes);
            List<Bilhete__c> bilhetesParaCriar = new List<Bilhete__c>();

            for (Object obj : rawInputs) {
                Map<String, Object> m = (Map<String, Object>) obj;
                bilhetesParaCriar.add(new Bilhete__c(
                    Order__c         = orderId,
                    Evento__c        = eventoId,
                    Fila__c          = (String) m.get('fila'),
                    // FIX 3 — Long em vez de Integer
                    NumeroLugar__c   = (Long) m.get('lugar'),
                    EstadoBilhete__c = 'Vendido'
                ));
            }

            insert bilhetesParaCriar;

            Order ord = new Order(Id = orderId);
            ord.QuantidadeBilhetes__c = bilhetesParaCriar.size();

            return 'PAGAMENTO_OK';

        } catch (Exception e) { return 'ERRO: ' + e.getMessage(); }
    }
}