<?php

include_once('class.YapoResultSet.php');

class YapoDb
{
    private $DBH;

    private $Data;

    protected $Debug = false;

    public $__ERRORS = array();

    public $__SetupParameters = array();

    private static $schema_cache = [];

    public function __construct($host, $dbname, $user, $password)
    {
        $this->__SetupParameters = array("mysql:host=$host;dbname=$dbname;charset=utf8", $user, $password);
        $this->DBH = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8", $user, $password);
        $this->DBH->exec('set names utf8');
        $this->DBH->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_WARNING);
    }

    public function SetDebug($debug)
    {
        $this->Debug = $debug;
    }

    public function TableDescription($table)
    {
        if (isset(self::$schema_cache[$table])) {
            return self::$schema_cache[$table];
        }
        $Keys = $this->DataSet("SHOW KEYS IN $table");
        $Fields = $this->DataSet("describe $table");
        $this->Clear();

        $keys = array();

        while ($Keys->Next()) {
            if (!is_array($keys[$Keys->Key_name])) {
                $keys[$Keys->Key_name] = array('Unique' => !$Keys->Non_unique,'Columns' => array());
            }
            $keys[$Keys->Key_name]['Columns'][] = $Keys->Column_name;
        }


        $fields = array();
        $primary_key = false;
        while ($Fields->Next()) {
            preg_match("/(.+)\((.+)\)/", $Fields->Type, $matches);
            $fields[$Fields->Field] = array(
                    'MajorType' => $matches[1],
                    'MinorType' => $matches[2],
                    'Type' => $Fields->Type,
                    'Null' => $Fields->Null == "NO" ? false : true,
                    'Key' => $Fields->Key,
                    'Extra' => $Fields->Extra
                );
            if (strtoupper($Fields->Key) == 'PRI') {
                $primary_key = $Fields->Field;
            }
        }

        self::$schema_cache[$table] = array("Keys" => $keys, "Fields" => $fields, "PrimaryKey" => $primary_key);
        return self::$schema_cache[$table];
    }

    public function GetLastInsertId()
    {
        return $this->DBH->lastInsertId();
    }

    public function Begin()
    {
        if ($this->DBH->inTransaction()) {
            return false; // do not nest; caller proceeds non-transactionally
        }
        $this->DBH->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        try {
            return $this->DBH->beginTransaction();
        } catch (\Throwable $e) {
            // beginTransaction failed (e.g. dropped connection) — restore the
            // normal error mode so the rest of the request isn't left throwing,
            // and let the caller fall back to the non-transactional path.
            error_log('YapoDb::Begin() transaction start failed: ' . $e->getMessage());
            $this->DBH->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_WARNING);
            return false;
        }
    }

    public function Commit()
    {
        try {
            if ($this->DBH->inTransaction()) {
                return $this->DBH->commit();
            }
            return false;
        } catch (\Throwable $e) {
            // Log the commit failure so a production failure leaves a trace,
            // then preserve the original propagation contract by re-throwing.
            error_log('YapoDb::Commit() failed: ' . $e->getMessage());
            throw $e;
        } finally {
            $this->DBH->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_WARNING);
        }
    }

    public function Rollback()
    {
        try {
            if ($this->DBH->inTransaction()) {
                return $this->DBH->rollBack();
            }
            return false;
        } catch (\Throwable $e) {
            error_log('YapoDb::Rollback() failed: ' . $e->getMessage());
            return false;
        } finally {
            $this->DBH->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_WARNING);
        }
    }

    public function GetCore($table)
    {
        return new YapoCore($this, $table);
    }

    public function Query($sql, $DataSet = null)
    {
        $this->Clear();
        if (is_array($DataSet)) {
            $this->SetData($DataSet);
        }
        return $this->DataSet($sql);
    }

    public function Execute($sql)
    {
        if ($this->Debug) {
            echo $sql;
            print_r($this->Data);
        }
        $cnt = 3;
        do {
            $Query = $this->DBH->prepare($sql);
            if (count($this->Data) > 0) {
                $Query->execute($this->Data);
            } else {
                $Query->execute();
            }
            $failed = $this->handle_errors($cnt--, $Query);
        } while (!$failed);
    }

    public function DataSet($sql)
    {
        if ($this->Debug) {
            echo $sql;
            print_r($this->Data);
        }
        $cnt = 3;
        do {
            $Query = $this->DBH->prepare($sql);
            if (count($this->Data) > 0) {
                $Query->execute($this->Data);
            } else {
                $Query->execute();
            }
            $failed = $this->handle_errors($cnt--, $Query);
        } while (!$failed);
        $result = new YapoResultSet($Query, $sql);

        $result->next();
        return $result;
    }

    public function handle_errors($cnt, $Query)
    {
        if ($cnt == 0) {
            return true;
        }
        switch ($Query->errorCode()) {
            case '00000': return true;
            case 'HY200':
                $this->DBH = new PDO($this->__SetupParameters[0], $this->__SetupParameters[1], $this->__SetupParameters[2]);
                $this->DBH->exec('set names utf8');
                $this->DBH->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_WARNING);
                return false;
            default: return true;
        }
    }

    public function Clear()
    {
        $this->Data = array();
    }

    public function __set($field, $value)
    {
        $this->Data[":$field"] = $value;
    }

    public function SetData($Data)
    {
        $this->Data = $Data;
    }

    public function ValidateField($field_def, $value)
    {
        if (stristr($field_def['MajorType'], 'int') ||
            stristr($field_def['MajorType'], 'float') ||
            stristr($field_def['MajorType'], 'double') ||
            stristr($field_def['MajorType'], 'real') ||
            stristr($field_def['MajorType'], 'decimal') ||
            stristr($field_def['MajorType'], 'numeric')) {
            return $value;
        } elseif (strtoupper($field_def['MajorType']) == 'TIME') {
            return "'" . date("H:i:s", strtotime($value)) . "'";
        } elseif (stristr($field_def['MajorType'], 'time')) {
            return "'" . date("Y-m-d H:i:s", strtotime($value)) . "'";
        } elseif (stristr($field_def['MajorType'], 'date')) {
            return "'" . date("Y-m-d", strtotime($value)) . "'";
        } elseif (strtoupper($field_def['MajorType']) == 'YEAR') {
            return "'" . date("Y", strtotime($value)) . "'";
        } elseif (stristr($field_def['MajorType'], 'text')) {
            // incomplete
        }
    }

}
