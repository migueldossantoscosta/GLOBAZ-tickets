public class BilheteiraController {
    
    public Id idDoEvento  {get;set;}
    public Id idDaAccount {get;set;}

    public BilheteiraController(ApexPages.StandardController controller) {
        this.idDoEvento  = ApexPages.currentPage().getParameters().get('idEvento');
        this.idDaAccount = null;
    }

    @RemoteAction
    public static List<String> getLugaresOcupados(Id eventoId) {
        List<String> ocupados = new List<String>();

        for (Bilhete__c b : [
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
            List<Evento__c> eventos = [
                SELECT Pricebook__c
                FROM Evento__c
                WHERE Id = :eventoId
                LIMIT 1
            ];

            if (eventos.isEmpty()) return 25.00;

            Evento__c evt = eventos[0];
            if (evt.Pricebook__c == null) return 25.00;

            List<PricebookEntry> pbes = [
                SELECT UnitPrice
                FROM PricebookEntry
                WHERE Pricebook2Id = :evt.Pricebook__c
                AND IsActive = true
                LIMIT 1
            ];

            if (pbes.isEmpty()) return 25.00;

            return pbes[0].UnitPrice;

        } catch (Exception e) {
            return 25.00;
        }
    }

    @RemoteAction
    public static String getMapaConfig(Id eventoId) {
        try {
            List<Evento__c> eventos = [
                SELECT MapaConfig__c
                FROM Evento__c
                WHERE Id = :eventoId
                LIMIT 1
            ];

            if (eventos.isEmpty()) {
                return 'ERRO: Evento não encontrado.';
            }

            Evento__c evt = eventos[0];

            if (String.isBlank(evt.MapaConfig__c)) {
                return 'ERRO: Mapa não configurado para este evento.';
            }

            return evt.MapaConfig__c;

        } catch (Exception e) {
            return 'ERRO: ' + e.getMessage();
        }
    }


    @RemoteAction
    public static String criarReserva(
        Id eventoId,
        Id accountId,
        String metodo,
        String nomeCompleto,
        String email
    ) {
        try {
            if (String.isBlank(nomeCompleto)) {
                return 'ERRO: Nome em falta.';
            }

            if (String.isBlank(email)) {
                return 'ERRO: Email em falta.';
            }

            Id finalAccountId;

            if (accountId != null) {
                List<Account> accs = [
                    SELECT Id, IsPersonAccount, Valido__c
                    FROM Account
                    WHERE Id = :accountId
                    LIMIT 1
                ];

                if (!accs.isEmpty()) {
                    finalAccountId = accs[0].Id;
                }
            }

            if (finalAccountId == null) {
                finalAccountId = criarOuObterPersonAccount(nomeCompleto, email);
            }

            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://bilheteira-loba.free.beeceptor.com/pagamento');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody('{"clienteEmail":"' + escapeJson(email) + '","status":"processar"}');
            req.setTimeout(10000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                return 'PAGAMENTO_RECUSADO';
            }

            Order ord = new Order(
                AccountId             = finalAccountId,
                Evento__c             = eventoId,
                EffectiveDate         = Date.today(),
                Status                = 'Draft',
                MetodoPagamento__c    = metodo,
                QuantidadeBilhetes__c = 0
            );
            insert ord;

            return ord.Id;

        } catch (Exception e) {
            return 'ERRO: ' + e.getMessage();
        }
    }

    @RemoteAction
    public static String processarPagamentoMock(Id orderId, Id eventoId, String jsonBilhetes) {
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://bilheteira-loba.free.beeceptor.com/pagamento');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody('{"orderId":"' + String.valueOf(orderId) + '","status":"confirmar"}');
            req.setTimeout(10000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                return 'PAGAMENTO_RECUSADO';
            }

            List<Evento__c> eventos = [
                SELECT Pricebook__c
                FROM Evento__c
                WHERE Id = :eventoId
                LIMIT 1
            ];

            if (eventos.isEmpty()) {
                return 'ERRO: Evento não encontrado.';
            }

            Evento__c evt = eventos[0];

            List<PricebookEntry> pbes = [
                SELECT Id, UnitPrice, Product2Id
                FROM PricebookEntry
                WHERE Pricebook2Id = :evt.Pricebook__c
                AND IsActive = true
                LIMIT 1
            ];

            if (pbes.isEmpty()) {
                return 'ERRO: Não existe PricebookEntry ativa para este evento.';
            }

            PricebookEntry pbe = pbes[0];

            List<Order> ords = [
                SELECT Id, AccountId
                FROM Order
                WHERE Id = :orderId
                LIMIT 1
            ];

            if (ords.isEmpty()) {
                return 'ERRO: Encomenda não encontrada.';
            }

            Order orderDados = ords[0];

            List<Object> rawInputs = (List<Object>) JSON.deserializeUntyped(jsonBilhetes);
            List<Bilhete__c> bilhetesParaCriar = new List<Bilhete__c>();
            List<OrderItem> produtosParaCriar  = new List<OrderItem>();

            for (Object obj : rawInputs) {
                Map<String, Object> m = (Map<String, Object>) obj;

                String filaRaw = (String) m.get('fila');
                String filaCurta = (filaRaw != null)
                    ? filaRaw.substring(0, Math.min(filaRaw.length(), 3))
                    : '';

                Long numeroLugar = Long.valueOf(String.valueOf(m.get('lugar')));

                bilhetesParaCriar.add(new Bilhete__c(
                    Order__c         = orderId,
                    Evento__c        = eventoId,
                    Account__c       = orderDados.AccountId,
                    Fila__c          = filaCurta,
                    NumeroLugar__c   = numeroLugar,
                    EstadoBilhete__c = 'Vendido'
                ));

                produtosParaCriar.add(new OrderItem(
                    OrderId          = orderId,
                    PricebookEntryId = pbe.Id,
                    Product2Id       = pbe.Product2Id,
                    Quantity         = 1,
                    UnitPrice        = pbe.UnitPrice
                ));
            }

            if (!produtosParaCriar.isEmpty()) {
                Order ordPre = new Order(
                    Id = orderId,
                    Pricebook2Id = evt.Pricebook__c
                );
                update ordPre;
            }

            if (!bilhetesParaCriar.isEmpty()) insert bilhetesParaCriar;
            if (!produtosParaCriar.isEmpty()) insert produtosParaCriar;

            Order ordFinal = new Order(
                Id = orderId,
                IVA__c = 23,
                QuantidadeBilhetes__c = bilhetesParaCriar.size(),
                Status = 'Activated'
            );
            update ordFinal;

            return 'PAGAMENTO_OK';

        } catch (Exception e) {
            return 'ERRO: ' + e.getMessage();
        }
    }

    private static Id criarOuObterPersonAccount(String nomeCompleto, String email) {
        List<Account> existentes = [
            SELECT Id, PersonEmail
            FROM Account
            WHERE IsPersonAccount = true
            AND PersonEmail = :email
            LIMIT 1
        ];

        if (!existentes.isEmpty()) {
            return existentes[0].Id;
        }

        Id paRecordTypeId = obterPersonAccountRecordTypeId();

        String firstName = '';
        String lastName  = '';

        List<String> partes = nomeCompleto != null
            ? nomeCompleto.trim().split('\\s+')
            : new List<String>();

        if (partes.isEmpty()) {
            firstName = 'Cliente';
            lastName  = 'Checkout';
        } else if (partes.size() == 1) {
            firstName = '';
            lastName  = partes[0];
        } else {
            firstName = partes[0];
            lastName  = partes[partes.size() - 1];
        }

        Account pa = new Account();
        pa.RecordTypeId = paRecordTypeId;
        pa.FirstName    = firstName;
        pa.LastName     = lastName;
        pa.PersonEmail  = email;
        pa.Valido__c    = true;

        insert pa;
        return pa.Id;
    }

    private static Id obterPersonAccountRecordTypeId() {
        List<RecordType> rts = [
            SELECT Id, Name, DeveloperName
            FROM RecordType
            WHERE SObjectType = 'Account'
            AND IsActive = true
            AND IsPersonType = true
            LIMIT 1
        ];

        if (rts.isEmpty()) {
            throw new AuraHandledException('Não existe Record Type de Person Account ativo.');
        }

        return rts[0].Id;
    }

    private static String escapeJson(String s) {
        if (s == null) return '';
        return s.replace('\\', '\\\\').replace('"', '\\"');
    }
}