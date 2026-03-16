public class BilheteiraController {
    
    // Variáveis para capturar dados da URL (para o botão automático)
    public Id idDoEvento {get;set;}
    public Id idDaAccount {get;set;}

    public BilheteiraController(ApexPages.StandardController controller) {
        // Captura os IDs da URL: ...?evtId=XXXX&accId=YYYY
        this.idDoEvento = ApexPages.currentPage().getParameters().get('evtId');
        this.idDaAccount = ApexPages.currentPage().getParameters().get('accId');
    }

    // Wrapper para os bilhetes que vêm do JSON
    public class BilheteInput {
        public String fila {get;set;}
        public Integer lugar {get;set;}
    }

    /**
     * PASSO 1 e 2: Cria a Order e os Bilhetes (Estado Pendente)
     */
    @RemoteAction
    public static String criarReserva(Id eventoId, Id accountId, String metodo, String jsonBilhetes) {
        try {
            // 1. Criar a Order com os campos obrigatórios que o Salesforce pediu
            Order ord = new Order(
                AccountId = accountId,
                Evento__c = eventoId,
                EffectiveDate = Date.today(),
                Status = 'Draft',
                MetodoPagamento__c = metodo,
                QuantidadeBilhetes__c = 0 
            );
            insert ord;

            // 2. Desserializar bilhetes e associar à Order
            List<BilheteInput> inputs = (List<BilheteInput>) JSON.deserialize(jsonBilhetes, List<BilheteInput>.class);
            List<Bilhete__c> bilhetesParaCriar = new List<Bilhete__c>();
            
            for(BilheteInput b : inputs) {
                bilhetesParaCriar.add(new Bilhete__c(
                    Order__c = ord.Id,
                    Evento__c = eventoId,
                    Account__c = accountId,
                    Fila__c = b.fila,
                    NumeroLugar__c = b.lugar,
                    EstadoBilhete__c = 'Pendente' // Fica aguardando o Step 3 (Banco)
                ));
            }
            
            if(!bilhetesParaCriar.isEmpty()) {
                insert bilhetesParaCriar;
                
                // Atualiza a quantidade na Order para o cálculo do Valor Final
                ord.QuantidadeBilhetes__c = bilhetesParaCriar.size();
                update ord;
            }
            
            return ord.Id; // Retornamos o ID para o ecrã do banco usar
            
        } catch (DmlException e) {
            if (e.getDmlType(0) == StatusCode.DUPLICATE_VALUE) {
                return 'ERRO: Um dos lugares já está ocupado. Por favor, escolha outro.';
            }
            return 'ERRO: ' + e.getDmlMessage(0);
        } catch (Exception e) {
            return 'ERRO: ' + e.getMessage();
        }
    }

    /**
     * PASSO 3: Callout ao Beeceptor e Finalização
     */
    @RemoteAction
    public static String processarPagamentoMock(Id orderId) {
        try {
            // 1. Buscar a Order e o seu Gateway ID gerado
            Order ord = [SELECT Id, GatewayId__c, ValorFinal__c FROM Order WHERE Id = :orderId LIMIT 1];
            
            // 2. Preparar o JSON dinâmico para o Beeceptor
            Map<String, Object> payload = new Map<String, Object>();
            payload.put('gateway_id', ord.GatewayId__c);
            payload.put('amount', ord.ValorFinal__c);
            payload.put('order_id', ord.Id);

            // 3. Configurar Callout
            Http h = new Http();
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://bilheteira-loba.free.beeceptor.com/pagamento'); // AJUSTA PARA O TEU LINK
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setBody(JSON.serialize(payload));
            
            HttpResponse res = h.send(req);
            
            if (res.getStatusCode() == 200) {
                // 4. Pagamento OK: Atualizar Bilhetes para Vendido (Dispara o Flow do PDF)
                List<Bilhete__c> bilhetes = [SELECT Id FROM Bilhete__c WHERE Order__c = :orderId];
                for(Bilhete__c b : bilhetes) {
                    b.EstadoBilhete__c = 'Vendido';
                }
                update bilhetes;
                
                // Opcional: Mudar status da Order para Activated se não houver bloqueios
                // ord.Status = 'Activated';
                // update ord;

                return 'PAGAMENTO_OK';
            } else {
                return 'Erro no Banco (Simulado): ' + res.getStatus();
            }
        } catch (Exception e) {
            return 'Erro na integração: ' + e.getMessage();
        }
    }
}