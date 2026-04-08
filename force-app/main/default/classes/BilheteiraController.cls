public class BilheteiraController {
    
    public Id idDoEvento  {get;set;}
    public Id idDaAccount {get;set;}

    public BilheteiraController(ApexPages.StandardController controller) {
        this.idDoEvento  = ApexPages.currentPage().getParameters().get('idEvento');

        // Primeiro, tenta obter o Account ID a partir do cookie (quando o utilizador está logado)
        String uid = ApexPages.currentPage().getCookies().get('globaz_uid') != null
            ? ApexPages.currentPage().getCookies().get('globaz_uid').getValue()
            : null;

        if (String.isNotBlank(uid)) {
            try {
                this.idDaAccount = (Id) uid;
            } catch (Exception e) {
                this.idDaAccount = null;
            }
        } else {
            // Em alternativa, tenta obter o Account ID passado pela URL
            String accParam = ApexPages.currentPage().getParameters().get('accId');
            if (String.isNotBlank(accParam)) {
                try {
                    this.idDaAccount = (Id) accParam;
                } catch (Exception e) {
                    this.idDaAccount = null;
                }
            } else {
                this.idDaAccount = null;
            }
        }
    }

    @RemoteAction
    public static List<String> getLugaresOcupados(Id eventoId) {
        List<String> ocupados = new List<String>();
        for (Bilhete__c b : [SELECT Fila__c, NumeroLugar__c, Pessoa__c FROM Bilhete__c WHERE Evento__c = :eventoId AND EstadoBilhete__c = 'Vendido']) {
            // Se a fila vier com prefixo (ex: SA-A), tentamos limpar para o mapa JS se necessário
            // No entanto, o mapa JS agora também usa prefixos nas chaves 'k' se quisermos.
            // Mas para compatibilidade com o que já está lá (fila original no JSON do mapa),
            // vamos garantir que a chave bata certo.
            String f = b.Fila__c;
            if (f != null && f.contains('-')) {
                // Se o prefixo for fixo, podemos remover, mas o mais seguro é manter f-n-p
                // e garantir que o JS saiba validar.
            }
            String k = b.Fila__c + '-' + b.NumeroLugar__c;
            if (String.isNotBlank(b.Pessoa__c)) k += '-' + b.Pessoa__c;
            ocupados.add(k);
        }
        return ocupados;
    }

    @RemoteAction
    public static Map<String, Decimal> getPrecosBilhetes(Id eventoId) {
        Map<String, Decimal> precos = new Map<String, Decimal>();
        try {
            List<Evento__c> eventos = [SELECT Pricebook__c FROM Evento__c WHERE Id = :eventoId LIMIT 1];
            if (eventos.isEmpty() || eventos[0].Pricebook__c == null) {
                precos.put('BLT-Geral', 25.00 * 1.23);
                precos.put('BLT-VIP', 75.00 * 1.23);
                precos.put('BLT-CAMAROTE', 95.00 * 1.23);
                return precos;
            }
            
            for (PricebookEntry pbe : [
                SELECT Product2.ProductCode, UnitPrice 
                FROM PricebookEntry 
                WHERE Pricebook2Id = :eventos[0].Pricebook__c 
                AND Product2.ProductCode IN ('BLT-Geral', 'BLT-VIP', 'BLT-CAMAROTE')
                AND IsActive = true
            ]) {
                precos.put(pbe.Product2.ProductCode, (pbe.UnitPrice * 1.23).setScale(2));
            }
        } catch (Exception e) {}
        return precos;
    }

    @RemoteAction
    public static Decimal getPrecoBilhete(Id eventoId) {
        Map<String, Decimal> precos = getPrecosBilhetes(eventoId);
        return precos.containsKey('BLT-Geral') ? precos.get('BLT-Geral') : 30.75;
    }

    @RemoteAction
    public static List<Map<String, Object>> getServicosExtras(Id eventoId) {
        try {
            List<Evento__c> eventos = [SELECT Pricebook__c FROM Evento__c WHERE Id = :eventoId LIMIT 1];
            if (eventos.isEmpty() || eventos[0].Pricebook__c == null) return new List<Map<String, Object>>();

            List<Map<String, Object>> results = new List<Map<String, Object>>();
            for (PricebookEntry pbe : [
                SELECT Id, Product2.Name, Product2.ProductCode, UnitPrice
                FROM PricebookEntry
                WHERE Pricebook2Id = :eventos[0].Pricebook__c
                AND IsActive = true
                AND Product2.ProductCode NOT IN ('BLT-Geral', 'BLT-VIP', 'BLT-CAMAROTE')
            ]) {
                results.add(new Map<String, Object>{
                    'id' => pbe.Id,
                    'name' => pbe.Product2.Name,
                    'price' => pbe.UnitPrice * 1.23,
                    'code' => pbe.Product2.ProductCode
                });
            }
            return results;
        } catch (Exception e) {
            return new List<Map<String, Object>>();
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
            // Se não há accountId, nome e email são obrigatórios
            if (accountId == null) {
                if (String.isBlank(nomeCompleto)) {
                    return 'ERRO: Nome em falta.';
                }
                if (String.isBlank(email)) {
                    return 'ERRO: Email em falta.';
                }
            }

            // Se há accountId mas email está vazio, buscar o email da conta
            String emailParaPagamento = email;
            if (accountId != null && String.isBlank(emailParaPagamento)) {
                List<Account> accsEmail = [
                    SELECT PersonEmail
                    FROM Account
                    WHERE Id = :accountId
                    AND IsPersonAccount = true
                    LIMIT 1
                ];
                if (!accsEmail.isEmpty() && String.isNotBlank(accsEmail[0].PersonEmail)) {
                    emailParaPagamento = accsEmail[0].PersonEmail;
                } else {
                    emailParaPagamento = 'sem-email@globaz.pt';
                }
            }

            // 1. Primeiro callout
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://bilheteira-loba.free.beeceptor.com/pagamento');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody('{"clienteEmail":"' + escapeJson(emailParaPagamento) + '","status":"processar"}');
            req.setTimeout(10000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() != 200) {
                return 'PAGAMENTO_RECUSADO';
            }

            // 2. Só depois do callout tratar da conta
            Id finalAccountId = null;

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
                finalAccountId = criarOuObterPersonAccount(nomeCompleto, emailParaPagamento);
            }

            // 3. Criar a Order
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
    public static String processarPagamentoMock(Id orderId, Id eventoId, String jsonBilhetes, String jsonExtras) {
        try {
            // Logica mock de pagamento (Beeceptor)
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

            List<Evento__c> eventos = [SELECT Pricebook__c FROM Evento__c WHERE Id = :eventoId LIMIT 1];
            if (eventos.isEmpty()) return 'ERRO: Evento não encontrado.';
            Evento__c evt = eventos[0];

            List<Order> ords = [SELECT Id, AccountId FROM Order WHERE Id = :orderId LIMIT 1];
            if (ords.isEmpty()) return 'ERRO: Encomenda não encontrada.';
            Order orderDados = ords[0];

            // Buscar PBEs para os diferentes tipos de bilhetes
            Map<String, PricebookEntry> codeToPbe = new Map<String, PricebookEntry>();
            for(PricebookEntry p : [
                SELECT Id, UnitPrice, Product2Id, Product2.ProductCode 
                FROM PricebookEntry 
                WHERE Pricebook2Id = :evt.Pricebook__c 
                AND Product2.ProductCode IN ('BLT-Geral', 'BLT-VIP', 'BLT-CAMAROTE')
                AND IsActive = true
            ]){
                codeToPbe.put(p.Product2.ProductCode, p);
            }

            List<OrderItem> produtosParaCriar  = new List<OrderItem>();
            List<Bilhete__c> bilhetesParaCriar = new List<Bilhete__c>();

            // Processar Bilhetes (Lugares)
            List<Object> rawBilhetes = (List<Object>) JSON.deserializeUntyped(jsonBilhetes);
            for (Object obj : rawBilhetes) {
                Map<String, Object> m = (Map<String, Object>) obj;
                String fila = (String) m.get('fila');
                Long lugar = Long.valueOf(String.valueOf(m.get('lugar')));
                
                String tipo = (String) m.get('tipo'); 
                if(String.isBlank(tipo)) tipo = 'BLT-Geral';
                
                PricebookEntry pbe = codeToPbe.containsKey(tipo) ? codeToPbe.get(tipo) : codeToPbe.get('BLT-Geral');

                bilhetesParaCriar.add(new Bilhete__c(
                    Order__c         = orderId,
                    Evento__c        = eventoId,
                    Account__c       = orderDados.AccountId,
                    Fila__c          = fila,
                    NumeroLugar__c   = lugar,
                    Pessoa__c        = (String)m.get('stand'),
                    EstadoBilhete__c = 'Vendido'
                ));

                if (pbe != null) {
                    produtosParaCriar.add(new OrderItem(
                        OrderId          = orderId,
                        PricebookEntryId = pbe.Id,
                        Product2Id       = pbe.Product2Id,
                        Quantity         = 1,
                        UnitPrice        = pbe.UnitPrice
                    ));
                }
            }

            // Processar Serviços Extras
            if (String.isNotBlank(jsonExtras)) {
                List<Object> rawExtras = (List<Object>) JSON.deserializeUntyped(jsonExtras);
                for (Object objE : rawExtras) {
                    Map<String, Object> e = (Map<String, Object>) objE;
                    Id pbeId = (Id) e.get('pbeId');
                    Decimal qty = Decimal.valueOf(String.valueOf(e.get('qty')));

                    if (qty > 0) {
                        List<PricebookEntry> extraPbes = [SELECT Id, UnitPrice, Product2Id FROM PricebookEntry WHERE Id = :pbeId LIMIT 1];
                        if (!extraPbes.isEmpty()) {
                            produtosParaCriar.add(new OrderItem(
                                OrderId          = orderId,
                                PricebookEntryId = extraPbes[0].Id,
                                Product2Id       = extraPbes[0].Product2Id,
                                Quantity         = qty,
                                UnitPrice        = extraPbes[0].UnitPrice
                            ));
                        }
                    }
                }
            }

            if (!produtosParaCriar.isEmpty()) {
                update new Order(Id = orderId, Pricebook2Id = evt.Pricebook__c);
                insert produtosParaCriar;
            }
            if (!bilhetesParaCriar.isEmpty()) {
                insert bilhetesParaCriar;
                
                // Enviar bilhetes por email automaticamente após pagamento
                List<Id> bilheteIds = new List<Id>();
                for(Bilhete__c b : bilhetesParaCriar) {
                    bilheteIds.add(b.Id);
                }
                EnviarBilhetePDF.enviarEmailFuturo(bilheteIds);
            }

            update new Order(
                Id = orderId,
                IVA__c = 23,
                QuantidadeBilhetes__c = bilhetesParaCriar.size(),
                Status = 'Activated'
            );

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

    @RemoteAction
    public static String getNomeAccount(Id accountId) {
        try {
            List<Account> accs = [
                SELECT FirstName, LastName
                FROM Account
                WHERE Id = :accountId
                AND IsPersonAccount = true
                LIMIT 1
            ];
            if (accs.isEmpty()) return '';
            return (accs[0].FirstName + ' ' + accs[0].LastName).trim();
        } catch (Exception e) {
            return '';
        }
    }

    private static String escapeJson(String s) {
        if (s == null) return '';
        return s.replace('\\', '\\\\').replace('"', '\\"');
    }
}