/**
 * AgentSelecionarLugares
 * ----------------------
 * Invocable action used by the GLO agent to automatically find N consecutive
 * available seats in the requested zone and reserve them for checkout.
 *
 * Seat-finding algorithm:
 *   1. Query all Bilhete__c records with EstadoBilhete__c = 'Vendido' for the
 *      event and build a Set<String> of occupied keys in "FILA-NUMERO" format.
 *   2. Try each candidate row (front rows first: A, B, C up to 20 seats;
 *      then D, E up to 24; then any other row requested).
 *   3. Within each row scan seat numbers 1..maxSeats looking for the first
 *      run of N consecutive free seats.
 *   4. Return the selected seats as a JSON array ready to be passed directly
 *      to AgentProcessarPagamento's fila/lugar inputs (first seat) and the
 *      full list for display.
 *
 * Row capacity reference (SBA-style default — matches EscolherLugar.page):
 *   A: 20 seats   B: 24 seats   C: 28 seats
 *   D: 30 seats   E: 32 seats   (fallback)
 */
public with sharing class AgentSelecionarLugares {

    // ------------------------------------------------------------------ Input
    public class Input {
        @InvocableVariable(label='ID do Evento' required=true)
        public String eventoId;

        @InvocableVariable(label='Quantidade de bilhetes' required=true)
        public Decimal quantidade;

        @InvocableVariable(
            label='Zona preferida (frente / meio / trás / qualquer)'
            required=false
        )
        public String zonaPreferida;
    }

    // ----------------------------------------------------------------- Output
    public class Output {
        /** Row letter of the FIRST selected seat (ready for AgentProcessarPagamento.fila) */
        @InvocableVariable(label='Fila (primeiro lugar)')
        public String fila;

        /** Seat number of the FIRST selected seat (ready for AgentProcessarPagamento.lugar) */
        @InvocableVariable(label='Número do lugar (primeiro lugar)')
        public Decimal lugar;

        /** Full JSON list: [{fila,lugar}, …] — one entry per ticket */
        @InvocableVariable(label='Lugares selecionados (JSON)')
        public String lugaresJson;

        /** Human-readable summary for the chat bubble */
        @InvocableVariable(label='Mensagem para o chat')
        public String mensagemChat;

        @InvocableVariable(label='Sucesso?')
        public Boolean sucesso;

        @InvocableVariable(label='Erro')
        public String erroMsg;
    }

    // ------------------------------------------------------------ Row catalog
    /**
     * Default seat counts per row — mirrors the SBA (Super Bock Arena) grid
     * embedded in EscolherLugar.page.  For other venue types this is a safe
     * conservative fallback; the algorithm simply stops when no free seat is
     * found within the declared capacity.
     */
    private static final Map<String, Integer> ROW_CAPACITY =
        new Map<String, Integer>{
            'A' => 20, 'B' => 24, 'C' => 28,
            'D' => 30, 'E' => 32, 'F' => 32,
            'G' => 32, 'H' => 30, 'I' => 28,
            'J' => 26, 'K' => 24, 'L' => 22,
            'M' => 20, 'N' => 18
        };

    /** Ordered lists of rows per zone */
    private static final List<String> ROWS_FRENTE = new List<String>{'A','B','C'};
    private static final List<String> ROWS_MEIO   = new List<String>{'D','E','F','G'};
    private static final List<String> ROWS_TRAS   = new List<String>{'H','I','J','K','L','M','N'};

    // -------------------------------------------------------------- Main body
    // -------------------------------------------------------------- Main body
    @InvocableMethod(
        label       = 'Agente — Selecionar Lugares Disponíveis'
        description = 'Encontra N lugares consecutivos disponíveis para o evento, priorizando a zona solicitada. Retorna a fila e número do primeiro lugar para o checkout.'
        category    = 'GLOBAZ Tickets'
    )
    public static List<Output> selecionarLugares(List<Input> inputs) {
        Output out = new Output();
        out.sucesso = false;

        try {
            Input inp = inputs[0];
            Id evId   = (Id) inp.eventoId;
            Integer qty = (inp.quantidade != null) ? inp.quantidade.intValue() : 1;
            if (qty < 1) qty = 1;

            // 1. Get Event Map Config to know actual capacities
            Evento__c evt = [SELECT MapaConfig__c FROM Evento__c WHERE Id = :evId LIMIT 1];
            Map<String, Integer> dynamicCapacity = parseCapacity(evt.MapaConfig__c);

            // 2. Build occupied set
            Set<String> occupied = new Set<String>();
            for (Bilhete__c b : [
                SELECT Fila__c, NumeroLugar__c
                FROM   Bilhete__c
                WHERE  Evento__c        = :evId
                AND    EstadoBilhete__c = 'Vendido'
            ]) {
                if (b.Fila__c != null && b.NumeroLugar__c != null) {
                    occupied.add(b.Fila__c + '-' + (Integer) b.NumeroLugar__c);
                }
            }

            // 3. Determine candidate row order based on requested zone
            List<String> candidateRows = buildCandidateRows(inp.zonaPreferida);

            // 4. Find N consecutive seats using dynamic capacity
            List<Map<String, Object>> chosen = findConsecutiveSeats(
                candidateRows, occupied, qty, dynamicCapacity
            );

            if (chosen == null || chosen.isEmpty()) {
                out.erroMsg      = 'Não foi possível encontrar ' + qty + ' lugar(es) consecutivo(s) disponível(is).';
                out.mensagemChat = '😔 Infelizmente não encontrei ' + qty
                    + ' lugar(es) consecutivo(s) disponível(is) na zona solicitada. '
                    + 'Queres tentar outra zona ou reduzir a quantidade?';
                return new List<Output>{ out };
            }

            // 5. Build outputs
            Map<String, Object> first = chosen[0];
            out.fila   = (String)  first.get('fila');
            out.lugar  = Decimal.valueOf(String.valueOf(first.get('lugar')));
            out.sucesso = true;

            // Build JSON list
            out.lugaresJson = JSON.serialize(chosen);

            // Build readable seat summary
            String seatList = '';
            for (Map<String, Object> seat : chosen) {
                seatList += '🪑 Fila ' + seat.get('fila') + ', Lugar ' + seat.get('lugar') + '\n';
            }

            String idLimpo = String.valueOf(evId);
            String mapUrl = 'https://orgfarm-64aee8f1dd-dev-ed.develop.my.site.com/globaztickets/EscolherLugar?idEvento=' + idLimpo;

            String zonaNome = zonaLabel(inp.zonaPreferida);
            out.mensagemChat =
                '✅ Encontrei ' + qty + ' lugar(es) consecutivo(s) ' + zonaNome + ':\n\n'
                + seatList
                + '\nPodes visualizar ou alterar no mapa:\n'
                + '📍 [🗺️ Ver Mapa de Lugares e Escolher Assento](' + mapUrl + ')';

        } catch (Exception e) {
            out.sucesso      = false;
            out.erroMsg      = e.getMessage();
            out.mensagemChat = '⚠️ Erro ao procurar lugares. Tenta novamente.';
        }

        return new List<Output>{ out };
    }

    // ---------------------------------------------------- Helper: Dynamic Capacity Parser
    private static Map<String, Integer> parseCapacity(String jsonConfig) {
        Map<String, Integer> capacities = new Map<String, Integer>();
        if (String.isBlank(jsonConfig)) return capacities;

        try {
            Map<String, Object> mapObj = (Map<String, Object>) JSON.deserializeUntyped(jsonConfig);
            String tipo = (String) mapObj.get('tipo');

            if (tipo == 'meoarena' || tipo == 'sba') {
                // SBA / MEO Structure: plateia_central, plateia_vip, etc.
                for (String key : mapObj.keySet()) {
                    if (mapObj.get(key) instanceof Map<String, Object>) {
                        Map<String, Object> section = (Map<String, Object>) mapObj.get(key);
                        if (section.containsKey('filas') && section.containsKey('colunas')) {
                            List<Object> rows = (List<Object>) section.get('filas');
                            Integer cols = (Integer) section.get('colunas');
                            for (Object r : rows) {
                                capacities.put((String)r, cols);
                            }
                        }
                    }
                }
            } else if (tipo == 'teatro' || tipo == 'aa') {
                // Teatro Structure: zonas -> filas/colunas
                List<Object> zonas = (List<Object>) mapObj.get('zonas');
                if (zonas == null) zonas = (List<Object>) mapObj.get('stands'); // Compat with AA

                if (zonas != null) {
                    for (Object zObj : zonas) {
                        Map<String, Object> zona = (Map<String, Object>) zObj;
                        if (zona.containsKey('filas') && zona.containsKey('colunas')) {
                            List<Object> rows = (List<Object>) zona.get('filas');
                            Integer cols = (Integer) zona.get('colunas');
                            for (Object r : rows) {
                                capacities.put((String)r, cols);
                            }
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('Error parsing map config: ' + e.getMessage());
        }
        return capacities;
    }

    // ---------------------------------------------------- Helper: row order
    private static List<String> buildCandidateRows(String zona) {
        List<String> rows = new List<String>();
        String z = (zona != null) ? zona.toLowerCase().normalizeSpace() : 'frente';

        if (z.contains('frent') || z.contains('front')) {
            rows.addAll(ROWS_FRENTE);
            rows.addAll(ROWS_MEIO);
            rows.addAll(ROWS_TRAS);
        } else if (z.contains('meio') || z.contains('middl') || z.contains('centr')) {
            rows.addAll(ROWS_MEIO);
            rows.addAll(ROWS_FRENTE);
            rows.addAll(ROWS_TRAS);
        } else if (z.contains('tr') || z.contains('back')) {
            rows.addAll(ROWS_TRAS);
            rows.addAll(ROWS_MEIO);
            rows.addAll(ROWS_FRENTE);
        } else {
            rows.addAll(ROWS_FRENTE);
            rows.addAll(ROWS_MEIO);
            rows.addAll(ROWS_TRAS);
        }
        return rows;
    }

    // ----------------------------------------- Helper: consecutive seat scan
    /**
     * Public helper to allow other classes (like AgentProcessarPagamento) to
     * trigger auto-recovery when seats are taken.
     */
    public static List<Map<String, Object>> findConsecutiveSeats(
        List<String> rowOrder,
        Set<String>  occupied,
        Integer      qty,
        Map<String, Integer> dynamicCapacity
    ) {
        for (String row : rowOrder) {
            // Use dynamic capacity if available, otherwise fallback to 20
            Integer maxSeat = dynamicCapacity.containsKey(row)
                ? dynamicCapacity.get(row)
                : 20;

            for (Integer start = 1; start <= maxSeat - qty + 1; start++) {
                Boolean allFree = true;
                for (Integer offset = 0; offset < qty; offset++) {
                    if (occupied.contains(row + '-' + (start + offset))) {
                        allFree = false;
                        break;
                    }
                }
                if (allFree) {
                    List<Map<String, Object>> seats = new List<Map<String, Object>>();
                    for (Integer offset = 0; offset < qty; offset++) {
                        seats.add(new Map<String, Object>{
                            'fila'  => row,
                            'lugar' => start + offset
                        });
                    }
                    return seats;
                }
            }
        }
        return null;
    }

    /**
     * Full recovery helper: Given an event and a quantity, finds the best
     * available consecutive seats.
     */
    public static List<Map<String, Object>> autoRecoverSeats(Id evId, Integer qty, String zonaPreferida) {
        // 1. Get Event Map Config
        Evento__c evt = [SELECT MapaConfig__c FROM Evento__c WHERE Id = :evId LIMIT 1];
        Map<String, Integer> dynamicCapacity = parseCapacity(evt.MapaConfig__c);

        // 2. Build occupied set
        Set<String> occupied = new Set<String>();
        for (Bilhete__c b : [
            SELECT Fila__c, NumeroLugar__c
            FROM   Bilhete__c
            WHERE  Evento__c        = :evId
            AND    EstadoBilhete__c = 'Vendido'
        ]) {
            if (b.Fila__c != null && b.NumeroLugar__c != null) {
                occupied.add(b.Fila__c + '-' + (Integer) b.NumeroLugar__c);
            }
        }

        // 3. Row order
        List<String> candidateRows = buildCandidateRows(zonaPreferida);

        // 4. Find
        return findConsecutiveSeats(candidateRows, occupied, qty, dynamicCapacity);
    }

    // ---------------------------------------------- Helper: zone display text
    private static String zonaLabel(String zona) {
        if (zona == null) return 'na frente';
        String z = zona.toLowerCase();
        if (z.contains('frent') || z.contains('front')) return 'na frente';
        if (z.contains('meio') || z.contains('middl'))  return 'no meio';
        if (z.contains('tr') || z.contains('back'))     return 'atrás';
        return '';
    }
}