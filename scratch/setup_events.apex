
List<Evento__c> evs = [SELECT Id, Name, MapaConfig__c, Pricebook__c, Recinto__r.Name FROM Evento__c];
Id stdPricebookId = Test.isRunningTest() ? Test.getStandardPricebookId() : [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;

Id prodGeral = [SELECT Id FROM Product2 WHERE ProductCode = 'BLT-Geral' LIMIT 1].Id;
Id prodVIP = [SELECT Id FROM Product2 WHERE ProductCode = 'BLT-VIP' LIMIT 1].Id;
Id prodCamarote = [SELECT Id FROM Product2 WHERE ProductCode = 'BLT-CAMAROTE' LIMIT 1].Id;

for (Evento__c ev : evs) {
    // 1. Create specific Pricebook for the event
    Pricebook2 pb = new Pricebook2(
        Name = 'Pricebook - ' + ev.Name,
        IsActive = true
    );
    insert pb;
    ev.Pricebook__c = pb.Id;

    // 2. Add Standard Prices (Mandatory before custom PB entries)
    // Check if entries already exist in standard PB to avoid duplicates
    try {
        insert new PricebookEntry(Pricebook2Id = stdPricebookId, Product2Id = prodGeral, UnitPrice = 25.0, IsActive = true);
        insert new PricebookEntry(Pricebook2Id = stdPricebookId, Product2Id = prodVIP, UnitPrice = 65.0, IsActive = true);
        insert new PricebookEntry(Pricebook2Id = stdPricebookId, Product2Id = prodCamarote, UnitPrice = 95.0, IsActive = true);
    } catch(Exception e) {}

    // 3. Add Custom Pricebook Entries
    insert new List<PricebookEntry>{
        new PricebookEntry(Pricebook2Id = pb.Id, Product2Id = prodGeral, UnitPrice = 30.0, IsActive = true),
        new PricebookEntry(Pricebook2Id = pb.Id, Product2Id = prodVIP, UnitPrice = 70.0, IsActive = true),
        new PricebookEntry(Pricebook2Id = pb.Id, Product2Id = prodCamarote, UnitPrice = 110.0, IsActive = true)
    };

    // 4. Set MapaConfig
    if (ev.Name.contains('HYBRID')) {
        // Fix MEO Arena - remove prefixes and start with A
        ev.MapaConfig__c = '{\r\n' +
            '  \"tipo\": \"meoarena\",\r\n' +
            '  \"palco\": \"PALCO\",\r\n' +
            '  \"titulo_pt\": \"PLATEIA SENTADA\",\r\n' +
            '  \"plateia_central\": {\r\n' +
            '    \"prefixo_fila\": \"\",\r\n' + // Removed P
            '    \"filas\": [\"A\",\"B\",\"C\",\"D\",\"E\",\"F\",\"G\",\"H\",\"I\",\"J\",\"K\",\"L\",\"M\",\"N\",\"O\",\"P\",\"Q\",\"R\",\"S\",\"T\",\"U\",\"V\"],\r\n' +
            '    \"colunas\": 12,\r\n' +
            '    \"x\": 348, \"y\": 450, \"gap_x\": 18, \"gap_y\": 20, \"seat_w\": 11, \"seat_h\": 11, \"zona\": \"z-floor\"\r\n' +
            '  },\r\n' +
            '  \"topo\": {\r\n' +
            '    \"prefixo_fila\": \"T\",\r\n' + // Keep T for Topo to avoid duplicate IDs if seats overlap
            '    \"filas\": [\"A\",\"B\",\"C\"],\r\n' +
            '    \"colunas\": 7,\r\n' +
            '    \"x\": 390, \"y\": 352, \"gap_x\": 18, \"gap_y\": 14, \"seat_w\": 14, \"seat_h\": 6, \"zona\": \"z-lateral\"\r\n' +
            '  }\r\n' +
            '}';
    } else if (ev.MapaConfig__c == null) {
        // Create generic map for other events
        ev.MapaConfig__c = '{\r\n' +
            '  \"tipo\": \"teatro\",\r\n' +
            '  \"palco\": \"PALCO\",\r\n' +
            '  \"zonas\": [\r\n' +
            '    {\r\n' +
            '      \"id\": \"plateia\", \"label\": \"Plateia Principal\", \"cor\": \"#4ade80\", \"posicao\": \"frente-centro\",\r\n' +
            '      \"filas\": [\"A\",\"B\",\"C\",\"D\",\"E\",\"F\",\"G\",\"H\",\"I\",\"J\"],\r\n' +
            '      \"colunas\": 14, \"prefixo_fila\": \"\"\r\n' +
            '    }\r\n' +
            '  ]\r\n' +
            '}';
    }
}
update evs;
