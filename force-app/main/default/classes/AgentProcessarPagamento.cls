public without sharing class AgentProcessarPagamento {

    public class Input {
        @InvocableVariable(label='orderId' required=true)
        public String orderId;

        @InvocableVariable(label='eventoId' required=true)
        public String eventoId;

        @InvocableVariable(label='tipoBilhete' required=true)
        public String tipoBilhete;

        @InvocableVariable(label='quantidade' required=true)
        public Integer quantidade;

        @InvocableVariable(label='fila' required=false)
        public String fila;

        @InvocableVariable(label='lugar' required=false)
        public Decimal lugar;

        @InvocableVariable(label='zona' required=false)
        public String zona;

        @InvocableVariable(label='extrasJson' required=false)
        public String extrasJson;
    }

    public class Output {
        @InvocableVariable(label='Sucesso?')
        public Boolean sucesso;

        @InvocableVariable(label='Mensagem para o chat')
        public String mensagemChat;

        @InvocableVariable(label='Número de bilhetes criados')
        public Integer totalBilhetes;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    @InvocableMethod(
        label       = 'Agente — Processar Pagamento e Criar Bilhetes'
        description = 'Confirma o pagamento com o gateway, cria os Bilhete__c e ativa a Order. Deve ser chamado após AgentCriarReservaAgent.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> processarPagamento(List<Input> inputs) {
        Output out = new Output();
        try {
            Input inp = inputs[0];

            Id ordId;
            Id evId;
            try {
                ordId = (Id) inp.orderId;
                evId  = (Id) inp.eventoId;
            } catch (Exception e) {
                out.sucesso = false;
                out.erroMsg = 'ID_INVALIDO';
                out.mensagemChat = '⚠️ Erro interno na transação. Por favor, reinicia o processo.';
                return new List<Output>{ out };
            }

            // Construir JSON de bilhetes baseado nos inputs simples (conforme YAML)
            String codigoBilhete = inp.tipoBilhete;
            if (codigoBilhete.equalsIgnoreCase('Geral'))    codigoBilhete = 'BLT-Geral';
            else if (codigoBilhete.equalsIgnoreCase('VIP'))  codigoBilhete = 'BLT-VIP';
            else if (codigoBilhete.equalsIgnoreCase('Camarote')) codigoBilhete = 'BLT-CAMAROTE';

            List<Map<String, Object>> bilhetesList = new List<Map<String, Object>>();
            Integer qtd = (inp.quantidade != null) ? inp.quantidade : 1;

            // Se não temos fila/lugar, vamos procurar automaticamente antes de prosseguir
            if (String.isBlank(inp.fila) || inp.lugar == null) {
                List<Map<String, Object>> autoSeats = AgentSelecionarLugares.autoRecoverSeats(evId, qtd, inp.zona);
                if (autoSeats != null && !autoSeats.isEmpty()) {
                    inp.fila = (String) autoSeats[0].get('fila');
                    inp.lugar = Decimal.valueOf(String.valueOf(autoSeats[0].get('lugar')));
                } else {
                    out.sucesso = false;
                    out.erroMsg = 'FILA_LUGAR_OBRIGATORIO';
                    out.mensagemChat = '⚠️ Não consegui encontrar lugares disponíveis automaticamente. Por favor, seleciona lugares no mapa.';
                    return new List<Output>{ out };
                }
            }

            for(Integer i=0; i < qtd; i++) {
                bilhetesList.add(new Map<String, Object>{
                    'fila'  => inp.fila,
                    'lugar' => inp.lugar.intValue() + i,
                    'tipo'  => codigoBilhete,
                    'stand' => inp.zona
                });
            }
            String bilhetesJsonFinal = JSON.serialize(bilhetesList);
            String extrasJsonFinal   = String.isNotBlank(inp.extrasJson) ? inp.extrasJson : '[]';

            // --- LOGICA ANTI-DUPLICIDADE ---
            // Se já existirem bilhetes para esta Order, significa que o pagamento já foi processado com sucesso.
            List<Bilhete__c> bilhetesExistentes = [SELECT Id FROM Bilhete__c WHERE Order__c = :ordId];
            if (!bilhetesExistentes.isEmpty()) {
                out.sucesso = true;
                out.totalBilhetes = bilhetesExistentes.size();
                
                List<Order> ords = [SELECT Account.FirstName FROM Order WHERE Id = :ordId LIMIT 1];
                String nome = !ords.isEmpty() ? ords[0].Account.FirstName : 'Cliente';
                
                List<Bilhete__c> blts = [SELECT Id FROM Bilhete__c WHERE Order__c = :ordId LIMIT 1];
                String firstBId = !blts.isEmpty() ? blts[0].Id : '';

                out.mensagemChat = '✅ *A tua compra já foi confirmada anteriormente, ' + nome + '!*\n\n'
                    + '🎫 Já tens ' + out.totalBilhetes + ' bilhete(s) garantidos para este evento.\n'
                    + '📧 O PDF já foi enviado para o teu e-mail.\n\n'
                    + '📍 [🗺️ Ver Meus Lugares no Mapa](https://orgfarm-64aee8f1dd-dev-ed.develop.my.site.com/globaztickets/EscolherLugar?idEvento=' + evId + ')\n'
                    + '🎫 [⬇ Download Bilhete (PDF)](https://orgfarm-64aee8f1dd-dev-ed.develop.my.site.com/globaztickets/GerarBilhetePDF?id=' + firstBId + ')\n\n'
                    + 'Posso ajudar-te com mais alguma coisa? 😊';
                return new List<Output>{ out };
            }

            // Reutilizar lógica existente
            String resultado = BilheteiraController.processarPagamentoMock(
                ordId,
                evId,
                bilhetesJsonFinal,
                extrasJsonFinal
            );

            if (resultado == 'PAGAMENTO_OK') {
                // Contar bilhetes criados
                Integer totalBilhetesCriados = [
                    SELECT COUNT() FROM Bilhete__c WHERE Order__c = :ordId
                ];
                out.sucesso       = true;
                out.totalBilhetes = totalBilhetesCriados;

                // Buscar detalhes da Order e do Promotor (Business Account)
                List<Order> ords = [
                    SELECT Account.PersonEmail, Account.FirstName, MetodoPagamento__c,
                           Evento__r.Account__r.Name, Evento__r.Account__r.Phone
                    FROM   Order WHERE Id = :ordId LIMIT 1
                ];
                
                String emailCliente = !ords.isEmpty() ? ords[0].Account.PersonEmail : '';
                String nomeCliente  = !ords.isEmpty() ? ords[0].Account.FirstName : 'Cliente';
                String metodo       = !ords.isEmpty() ? ords[0].MetodoPagamento__c : 'Cartão';
                String promotorNome = (!ords.isEmpty() && ords[0].Evento__r.Account__r != null) ? ords[0].Evento__r.Account__r.Name : 'GLOBAZ';
                String promotorTel  = (!ords.isEmpty() && ords[0].Evento__r.Account__r != null) ? ords[0].Evento__r.Account__r.Phone : '910 000 000';

                String msgBase = '🎉 *Compra confirmada, ' + nomeCliente + '!*\n\n'
                    + '🎫 ' + totalBilhetesCriados + ' bilhete(s) reservado(s) com sucesso.\n';

                if (metodo == 'MBWay') {
                    msgBase += '📱 *Pagamento via MBWay:*\n'
                        + 'Total para o promotor (*' + promotorNome + '*): **' + promotorTel + '**\n'
                        + '🔗 [📱 Abrir App MBWay](https://globaz-tickets.force.com/qr?order=' + ordId + ')\n\n';
                } else if (metodo == 'Multibanco') {
                    String ref = String.valueOf(Math.abs(ordId.hashCode())).left(9);
                    ref = ref.substring(0,3) + ' ' + ref.substring(3,6) + ' ' + ref.substring(6,9);
                    msgBase += '🏧 *Dados para Multibanco:*\n'
                        + '   Entidade: **12345** | Ref: **' + ref + '**\n'
                        + '🔗 [📄 Ver Entidade e Referência](https://globaz-tickets.force.com/checkout?order=' + ordId + ')\n\n';
                } else {
                    msgBase += '💳 *Pagamento via Cartão:*\n'
                        + 'Clica no link para pagar de forma segura:\n'
                        + '🔗 [💳 PAGAR AGORA](https://globaz-tickets.force.com/checkout?order=' + ordId + ')\n\n';
                }

                List<Bilhete__c> blts = [SELECT Id FROM Bilhete__c WHERE Order__c = :ordId LIMIT 1];
                String firstBId = !blts.isEmpty() ? blts[0].Id : '';

                out.mensagemChat = msgBase
                    + '📧 O teu bilhete PDF já foi enviado para o e-mail *' + emailCliente + '* e está prontinho a usar!\n\n'
                    + '📍 [🗺️ Ver Meus Lugares no Mapa e Detalhes](https://orgfarm-64aee8f1dd-dev-ed.develop.my.site.com/globaztickets/EscolherLugar?idEvento=' + evId + ')\n'
                    + '🎫 [⬇ Download Bilhete (PDF)](https://orgfarm-64aee8f1dd-dev-ed.develop.my.site.com/globaztickets/GerarBilhetePDF?id=' + ordId + ')\n\n'
                    + 'Posso ajudar-te com mais alguma coisa? 😊';

                // Disparar envio de email assíncrono
                if (String.isNotBlank(emailCliente)) {
                    BilheteiraController.enviarEmailComBilhete(ordId, emailCliente, nomeCliente);
                }

            } else if (resultado == 'PAGAMENTO_RECUSADO') {
                out.sucesso      = false;
                out.erroMsg      = 'PAGAMENTO_RECUSADO';
                out.mensagemChat = '❌ O pagamento foi recusado.\n'
                    + 'Queres tentar com outro método? (MBWay, Cartão, MB, Transferência)';

            } else if (resultado == 'ERRO: SEAT_TAKEN') {
                // AUTO-RECOVERY LOGIC
                List<Map<String, Object>> newSeats = AgentSelecionarLugares.autoRecoverSeats(evId, qtd, inp.zona);
                
                if (newSeats != null && !newSeats.isEmpty()) {
                    String seatList = '';
                    String newFila = (String) newSeats[0].get('fila');
                    List<String> seatNums = new List<String>();
                    for (Map<String, Object> s : newSeats) {
                        seatNums.add(String.valueOf(s.get('lugar')));
                        seatList += '🪑 Fila ' + s.get('fila') + ', Lugar ' + s.get('lugar') + '\n';
                    }

                    out.sucesso = false;
                    out.erroMsg = 'SEAT_TAKEN_RECOVERED';
                    out.mensagemChat = 'Os lugares na Fila ' + inp.fila + ' acabaram de ser ocupados, mas já reservei para ti os dois melhores disponíveis logo a seguir:\n\n'
                        + seatList + '\nAvançamos com estes?';
                } else {
                    out.sucesso      = false;
                    out.erroMsg      = 'SEAT_TAKEN';
                    out.mensagemChat = '😔 Infelizmente os lugares que escolheste já não estão disponíveis e não encontrei outros similares. Queres escolher novos lugares no mapa?';
                }
            } else {
                out.sucesso      = false;
                out.erroMsg      = resultado;
                out.mensagemChat = '⚠️ Erro no processamento: '
                    + resultado.replace('ERRO: ', '')
                    + '\nContacta o suporte se o problema persistir.';
            }

        } catch (Exception e) {
            out.sucesso      = false;
            out.erroMsg      = e.getMessage();
            out.mensagemChat = '⚠️ Erro inesperado no pagamento. Tenta novamente.';
        }
        return new List<Output>{ out };
    }
}