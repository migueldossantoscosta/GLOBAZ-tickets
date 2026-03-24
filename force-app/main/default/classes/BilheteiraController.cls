public class BilheteiraController {
    
    public Id idDoEvento  {get;set;}
    public Id idDaAccount {get;set;}

    public BilheteiraController(ApexPages.StandardController controller) {
       this.idDoEvento  = 'a03d200001fwxUEAAY'; 
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

    @RemoteAction
    public static Decimal getPrecoBilhete(Id eventoId) {
        try {
            // Busca o Pricebook que o Flow associou ao Evento
            Evento__c evt = [SELECT Pricebook__c FROM Evento__c WHERE Id = :eventoId LIMIT 1];
            if (evt.Pricebook__c == null) return 25.00; // Valor de fallback caso o flow não tenha corrido

            // Busca o preço no Pricebook Entry (assumindo 1 produto por evento)
            PricebookEntry pbe = [
                SELECT UnitPrice 
                FROM PricebookEntry 
                WHERE Pricebook2Id = :evt.Pricebook__c 
                AND IsActive = true 
                LIMIT 1
            ];
            return pbe.UnitPrice;
        } catch (Exception e) {
            return 25.00; // Fallback para testes
        }
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
            // 1. Simulação de Callout de Pagamento
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

            // 2. Obter o Pricebook do Evento e a respetiva Entry (Preço)
            Evento__c evt = [SELECT Pricebook__c FROM Evento__c WHERE Id = :eventoId LIMIT 1];
            
            // Buscamos a Pricebook Entry para saber o Preço Unitário e o ID do Produto
            PricebookEntry pbe = [
                SELECT Id, UnitPrice, Product2Id 
                FROM PricebookEntry 
                WHERE Pricebook2Id = :evt.Pricebook__c 
                AND IsActive = true 
                LIMIT 1
            ];

            // 3. Preparar as listas para inserção em massa (Bulk)
            List<Object> rawInputs = (List<Object>) JSON.deserializeUntyped(jsonBilhetes);
            List<Bilhete__c> bilhetesParaCriar = new List<Bilhete__c>();
            List<OrderItem> produtosParaCriar = new List<OrderItem>();
            Order orderDados = [SELECT AccountId FROM Order WHERE Id = :orderId LIMIT 1];

            for (Object obj : rawInputs) {
                Map<String, Object> m = (Map<String, Object>) obj;
                String filaRaw = (String) m.get('fila');
                String filaCurta = (filaRaw != null) ? filaRaw.substring(0, Math.min(filaRaw.length(), 3)) : '';

                bilhetesParaCriar.add(new Bilhete__c(
                    Order__c         = orderId,
                    Evento__c        = eventoId,
                    Account__c       = orderDados.AccountId, // <-- ESTA É A LINHA QUE FALTA!
                    Fila__c          = filaCurta,
                    NumeroLugar__c   = Long.valueOf(String.valueOf(m.get('lugar'))),
                    EstadoBilhete__c = 'Vendido'
                ));

                // Criar o Order Product (Objeto Standard - OrderItem)
                // Isto é o que faz o "Order Amount" deixar de ser zero
                produtosParaCriar.add(new OrderItem(
                    OrderId = orderId,
                    PricebookEntryId = pbe.Id,
                    Product2Id = pbe.Product2Id,
                    Quantity = 1,
                    UnitPrice = pbe.UnitPrice
                ));
            }

            // 4. Inserir registos na base de dados
            if(!bilhetesParaCriar.isEmpty()) insert bilhetesParaCriar;
            if(!produtosParaCriar.isEmpty()) {
                // Antes de inserir produtos, a Order precisa de ter o PricebookId definido
                Order ordPre = new Order(Id = orderId, Pricebook2Id = evt.Pricebook__c);
                update ordPre;
                
                insert produtosParaCriar;
            }

            // 5. Atualizar a Order com Totais, IVA e Quantidade
            Order ordFinal = new Order(Id = orderId);
            ordFinal.IVA__c = 23; // Define automaticamente os 23%
            ordFinal.QuantidadeBilhetes__c = bilhetesParaCriar.size();
            ordFinal.Status = 'Activated'; // Ativa a encomenda
            
            update ordFinal;

            return 'PAGAMENTO_OK';

        } catch (Exception e) {
            return 'ERRO: ' + e.getMessage();
        }
    }
}