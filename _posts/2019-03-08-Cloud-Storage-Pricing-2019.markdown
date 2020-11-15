---
layout: post
title: "Cloud Storage Pricing, Revisited"
date: 2019-03-08 05:34:05 -0700
updated: Jun 13, 2019
categories: [Backup]
tags: ["Cloud Storage", "Backup"]
excerpt: Updated cloud storage pricing as of March 2019 
---

Revisiting the cloud storage pricing a year later. 

* TOC
{:toc}

## Cost comparison

This is the costs of cloud storage as of the date of this posting. Some services specify cost in euros or russian rubbles; this table contains prices in USD converted at the date of the publication. 
This table is sortable and searchable for your enjoyment.

<style> 
 td.red {
        background-color: #FEA18E;
    }
 td.orange {
        background-color: #FED796;
    }
 td.yellow {
        background-color: #FEFCA2;
    }
 td.green {
        background-color: #B7E694;
    }
</style>

<link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.10.19/css/jquery.dataTables.min.css"/>
<script type="text/javascript" src="https://code.jquery.com/jquery-3.3.1.js"></script>
<script type="text/javascript" src="https://cdn.datatables.net/1.10.19/js/jquery.dataTables.min.js"></script>
<script>
	$(document).ready(function() {
	    $('#cloudstorage').DataTable( 
        {
            "paging" : false,
            "data-page-length": 50,
	        "ajax": '{{ "/assets/cloudstorage.json" | relative_url }}',
            "columnDefs": [ 
             {
                "targets": [9, 10, 11, 12, 13, 14, 15, 16, 17],
                "data": function ( row, type, set, meta ) 
                {
                    var max_size        = row[4]? row[4].replace(/[\$,]/g, '') * 1 : "";
                    var store_tb_mon    = row[5]? row[5].replace(/[\$,]/g, '') * 1 : "";
                    var min_mon         = row[6]? row[6].replace(/[\$,]/g, '') * 1 : "";
                    var store_mon       = row[7]? row[7].replace(/[\$,]/g, '') * 1 : "";
                    var limit           =  $('th').eq(meta.col).html().replace(/[TB]/g,'') * 1;
 
                    var value = !store_tb_mon ? 
                        (limit <= max_size ? store_mon : "" ) 
                    :   ((!max_size || (limit <= max_size)) ? 
                                        Math.max(min_mon, limit * store_tb_mon)
                                        : "" );
                    return value;
                },

                "createdCell": function (td, value, rowData, row, col) 
                {
                    if (value)
                    {
                        value = (parseFloat(Math.round(100*value))/100).toFixed(2);

                        if  (value <= 5) 
                            $(td).addClass('green');
                        else if (value <= 9)
                            $(td).addClass('yellow');
                        else if (value <= 12)
                            $(td).addClass('orange');
                        else if (value > 12)
                            $(td).addClass('red');

                        $(td).html("$" + value);                            
                    }
                    else
                        $(td).html("");
                }
            } ]
          } 
        );
	} );
</script>

<table id="cloudstorage" class="compact" style="width:100%"  data-order='[[ 10, "asc" ]]'>
        <thead>
            <tr>
                <th>Provider</th>
                <th>Tier</th>
                <th>Protocol</th>
                <th>Comment</th>
                <th>Max, TB</th>
                <th>Store, $/TB/Mon</th>
                <th>Min, $/Mon</th>
                <th>Store, $/Mon</th>
                <th>Egress, $/GB</th>
                <th>0.5 TB</th>
                <th>1 TB</th>
                <th>2 TB</th>
                <th>4 TB</th>
                <th>5 TB</th>
                <th>6 TB</th>
                <th>8 TB</th>
                <th>10 TB</th>
                <th>12 TB</th>
            </tr>
        </thead>
        <tfoot>
            <tr>
                <th>Provider</th>
                <th>Tier</th>
                <th>Protocol</th>
                <th>Comment</th>
                <th>Max, TB</th>
                <th>Store, $/TB/Mon</th>
                <th>Min, $/Mon</th>
                <th>Store, $/Mon</th>
                <th>Egress, $/GB</th>
                <th>0.5 TB</th>
                <th>1 TB</th>
                <th>2 TB</th>
                <th>4 TB</th>
                <th>5 TB</th>
                <th>6 TB</th>
                <th>8 TB</th>
                <th>10 TB</th>
                <th>12 TB</th>
            </tr>
        </tfoot>
    </table>


## Legend
<table style="width:auto">
<thead> 
    <th class="block" style="font-weight: bold">How do you feel about it</th> 
    <th class="block" style="font-weight: bold">Price up to</th>

</thead>
 <tr><td>Super Awesome</td>     <td class="green">$5.00</td>    </tr> 
 <tr><td>OK-ish</td>            <td class="yellow">$9.00</td>   </tr>
 <tr><td>Borderline</td>        <td class="orange">$12.00</td>  </tr>
 <tr><td>My wallet hurts!</td>  <td class="red"> $12.00+</td>   </tr>

</table>

## Notes
- Glacier and Azure Archive storage require blob level management and will not be supported in Hyper Backup or any other third party backup software due to thawing latency. It can however be used for sync. Generally Archival storage is not suitable for backup
- Synology Office backup possible via HyperBackup, which automatically enabled Home folders backup, which includes CloudStation/Drive data. 
- Backblaze B2 is not supported by Synology’s HyperBackup. Synology [promised B2 support in Hyper Backup in 2018](https://www.reddit.com/r/synology/comments/6r29m8/please_help_get_backblaze_b2_supported_as_a/) but hasn't delivered (Yet?).
- CrashPlan provides unlimited backup for $10/month per seat. A consideration for aggregated backup strategy.
- Empty cells denote either zero cost or lack of support for specified sizes.

## Acknowledgments
- [Apple Numbers](https://www.apple.com/numbers/) -- spreadsheet software with built-in support for currency conversion and smart coloring
- [Data Tables](https://datatables.net) -- Sortable and searchable table control library

## History

|------|------|
|Mar 08, 2019 | initial publication|
|Mar 11, 2019 | Added cell highliting and data auto-calculaton<br>Google 2TB Tier -- updating cost to annual billing<br>Added Legend|
|Mar 18, 2019 | Updated to reflect price increase for Wasabi UE plan for new customers. Existing customers can retain their current cost structure|
|Jun 13, 2019 | Removed Wasabi Legacy plan since it seems to be completely discontinued.

